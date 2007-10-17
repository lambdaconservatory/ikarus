
(library (ikarus hash-tables)
   (export make-eq-hashtable hashtable-ref hashtable-set! hashtable?
           hashtable-size hashtable-delete! hashtable-contains?
           hashtable-update! hashtable-keys hashtable-mutable?
           hashtable-clear!)
   (import 
     (ikarus system $pairs)
     (ikarus system $vectors)
     (ikarus system $tcbuckets)
     (ikarus system $fx)
     (except (ikarus) make-eq-hashtable hashtable-ref hashtable-set! hashtable?
             hashtable-size hashtable-delete! hashtable-contains?
             hashtable-update! hashtable-keys hashtable-mutable?
             hashtable-clear!))

   (define-struct hasht (vec count tc mutable?))

  ;;; directly from Dybvig's paper
  (define tc-pop
    (lambda (tc)
      (let ([x ($car tc)])
        (if (eq? x ($cdr tc))
            #f
            (let ([v ($car x)])
              ($set-car! tc ($cdr x))
              ($set-car! x #f)
              ($set-cdr! x #f)
              v)))))

  (define-syntax inthash
    (syntax-rules ()
      [(_ x) x]))

  ;;; assq-like lookup
  (define direct-lookup 
    (lambda (x b)
      (if (fixnum? b)
          #f
          (if (eq? x ($tcbucket-key b))
              b
              (direct-lookup x ($tcbucket-next b))))))

  (define rehash-lookup
    (lambda (h tc x)
      (cond
        [(tc-pop tc) =>
         (lambda (b)
           (if (eq? ($tcbucket-next b) #f)
               (rehash-lookup h tc x)
               (begin
                 (re-add! h b)
                 (if (eq? x ($tcbucket-key b))
                     b
                     (rehash-lookup h tc x)))))]
        [else #f])))

  (define get-bucket-index
    (lambda (b)
      (let ([next ($tcbucket-next b)])
        (if (fixnum? next)
            next
            (get-bucket-index next)))))

  (define replace!
    (lambda (lb x y)
      (let ([n ($tcbucket-next lb)])
        (cond
          [(eq? n x) 
           ($set-tcbucket-next! lb y)
           (void)]
          [else
           (replace! n x y)]))))

  (define re-add! 
    (lambda (h b)
      (let ([vec (hasht-vec h)]
            [next ($tcbucket-next b)])
        ;;; first remove it from its old place
        (let ([idx 
               (if (fixnum? next)
                   next
                   (get-bucket-index next))])
          (let ([fst ($vector-ref vec idx)])
            (cond
              [(eq? fst b) 
               ($vector-set! vec idx next)]
              [else 
               (replace! fst b next)])))
        ;;; reset the tcbucket-tconc FIRST
        ($set-tcbucket-tconc! b (hasht-tc h))
        ;;; then add it to the new place
        (let ([k ($tcbucket-key b)])
          (let ([ih (inthash (pointer-value k))])
            (let ([idx ($fxlogand ih ($fx- ($vector-length vec) 1))])
              (let ([n ($vector-ref vec idx)])
                ($set-tcbucket-next! b n)
                ($vector-set! vec idx b)
                (void))))))))


  (define unlink! 
    (lambda (h b)
      (let ([vec (hasht-vec h)]
            [next ($tcbucket-next b)])
        ;;; first remove it from its old place
        (let ([idx 
               (if (fixnum? next)
                   next
                   (get-bucket-index next))])
          (let ([fst ($vector-ref vec idx)])
            (cond
              [(eq? fst b) 
               ($vector-set! vec idx next)]
              [else 
               (replace! fst b next)])))
        ;;; set next to be #f, denoting, not in table
        ($set-tcbucket-next! b #f))))

  (define (get-bucket h x)
    (let ([pv (pointer-value x)]
          [vec (hasht-vec h)])
      (let ([ih (inthash pv)])
        (let ([idx ($fxlogand ih ($fx- ($vector-length vec) 1))])
          (let ([b ($vector-ref vec idx)])
            (or (direct-lookup x b)
                (rehash-lookup h (hasht-tc h) x)))))))

  (define (get-hash h x v)
    (cond
      [(get-bucket h x) =>
       (lambda (b) ($tcbucket-val b))]
      [else v]))

  (define (in-hash? h x) 
    (and (get-bucket h x) #t))

  (define (del-hash h x)
    (cond
      [(get-bucket h x) => (lambda (b) (unlink! h b))]))

  (define put-hash!
    (lambda (h x v)
      (let ([pv (pointer-value x)]
            [vec (hasht-vec h)])
        (let ([ih (inthash pv)])
          (let ([idx ($fxlogand ih ($fx- ($vector-length vec) 1))])
            (let ([b ($vector-ref vec idx)])
              (cond
                [(or (direct-lookup x b) (rehash-lookup h (hasht-tc h) x))
                 =>
                 (lambda (b) 
                   ($set-tcbucket-val! b v)
                   (void))]
                [else 
                 (let ([bucket
                        ($make-tcbucket (hasht-tc h) x v ($vector-ref vec idx))])
                   (if ($fx= (pointer-value x) pv)
                       ($vector-set! vec idx bucket)
                       (let* ([ih (inthash (pointer-value x))]
                              [idx 
                               ($fxlogand ih ($fx- ($vector-length vec) 1))])
                         ($set-tcbucket-next! bucket ($vector-ref vec idx))
                         ($vector-set! vec idx bucket))))
                 (let ([ct (hasht-count h)])
                   (set-hasht-count! h ($fxadd1 ct))
                   (when ($fx> ct ($vector-length vec))
                     (enlarge-table h)))])))))))


          
  (define (update-hash! h x proc default)
    (cond
      [(get-bucket h x) =>
       (lambda (b) ($set-tcbucket-val! b (proc ($tcbucket-val b))))]
      [else (put-hash! h x (proc default))]))



  (define insert-b
    (lambda (b vec mask)
      (let* ([x ($tcbucket-key b)]
             [pv (pointer-value x)]
             [ih (inthash pv)]
             [idx ($fxlogand ih mask)]
             [next ($tcbucket-next b)])
        ($set-tcbucket-next! b ($vector-ref vec idx))
        ($vector-set! vec idx b)
        (unless (fixnum? next)
          (insert-b next vec mask)))))

  (define move-all
    (lambda (vec1 i n vec2 mask)
      (unless ($fx= i n)
        (let ([b ($vector-ref vec1 i)])
          (unless (fixnum? b)
            (insert-b b vec2 mask))
          (move-all vec1 ($fxadd1 i) n vec2 mask)))))

  (define enlarge-table
    (lambda (h)
      (let* ([vec1 (hasht-vec h)]
             [n1 ($vector-length vec1)]
             [n2 ($fxsll n1 1)]
             [vec2 (make-base-vec n2)])
        (move-all vec1 0 n1 vec2 ($fx- n2 1))
        (set-hasht-vec! h vec2))))

  (define init-vec
    (lambda (v i n)
      (if ($fx= i n)
          v
          (begin
            ($vector-set! v i i)
            (init-vec v ($fxadd1 i) n)))))

  (define make-base-vec
    (lambda (n)
      (init-vec (make-vector n) 0 n)))

  (define (clear-hash! h) 
    (let ([v (hasht-vec h)])
      (init-vec v 0 (vector-length v)))
    (set-hasht-tc! h 
      (let ([x (cons #f #f)])
        (cons x x)))
    (set-hasht-count! h 0))

  (define (get-keys h)
    (let ([v (hasht-vec h)] [n (hasht-count h)])
      (let ([kv (make-vector n)])
        (let f ([i ($fxsub1 n)] [j ($fxsub1 (vector-length v))] [kv kv] [v v])
          (cond
            [($fx= i -1) kv]
            [else 
             (let ([b ($vector-ref v j)])
               (if (fixnum? b) 
                   (f i ($fxsub1 j) kv v)
                   (f (let f ([i i] [b b] [kv kv])
                        ($vector-set! kv i ($tcbucket-key b))
                        (let ([b ($tcbucket-next b)]
                              [i ($fxsub1 i)])
                          (cond
                            [(fixnum? b) i]
                            [else (f i b kv)])))
                      ($fxsub1 j) kv v)))])))))

  ;;; public interface
  (define (hashtable? x) (hasht? x))

  (define make-eq-hashtable
    (case-lambda
      [()
       (let ([x (cons #f #f)])
         (let ([tc (cons x x)])
           (make-hasht (make-base-vec 32) 0 tc #t)))]
      [(k) 
       (if (and (or (fixnum? k) (bignum? k))
                (>= k 0))
           (make-eq-hashtable)
           (error 'make-eq-hashtable
             "invalid initial capacity ~s" k))]))

  (define hashtable-ref
    (lambda (h x v)
      (if (hasht? h)
          (get-hash h x v)
          (error 'hashtable-ref "~s is not a hash table" h))))


  (define hashtable-contains?
    (lambda (h x)
      (if (hasht? h)
          (in-hash? h x)
          (error 'hashtable-contains? "~s is not a hash table" h))))

  (define hashtable-set!
    (lambda (h x v)
      (if (hasht? h)
          (if (hasht-mutable? h) 
              (put-hash! h x v)
              (error 'hashtable-set! "~s is immutable" h))
          (error 'hashtable-set! "~s is not a hash table" h))))


  (define hashtable-update!
    (lambda (h x proc default)
      (if (hasht? h)
          (if (hasht-mutable? h)
              (if (procedure? proc)
                  (update-hash! h x proc default)
                  (error 'hashtable-update! "~s is not a procedure" proc))
              (error 'hashtable-update! "~s is immutable" h))
          (error 'hashtable-update! "~s is not a hash table" h))))


  (define hashtable-size
    (lambda (h)
      (if (hasht? h) 
          (hasht-count h)
          (error 'hashtable-size "~s is not a hash table" h))))

  (define hashtable-delete!
    (lambda (h x) 
      ;;; FIXME: should shrink table if number of keys drops below
      ;;; (sqrt (vector-length (hasht-vec h)))
      (if (hasht? h)
          (if (hasht-mutable? h)
              (del-hash h x)
              (error 'hashtable-delete! "~s is immutable" h))
          (error 'hashtable-delete! "~s is not a hash table" h))))

  (define (hashtable-keys h)
    (if (hasht? h) 
        (get-keys h)
        (error 'hashtable-keys "~s is not a hash table" h)))

  (define (hashtable-mutable? h)
    (if (hasht? h) 
        (hasht-mutable? h)
        (error 'hashtable-mutable? "~s is not a hash table" h)))

  (define (hashtable-clear! h)
    (if (hasht? h) 
        (if (hasht-mutable? h)
            (clear-hash! h)
            (error 'hashtable-clear! "~s is immutable" h))
        (error 'hashtable-clear! "~s is not a hash table" h)))
)