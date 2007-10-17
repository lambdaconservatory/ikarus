

(library (ikarus structs)
  (export
    make-struct-type struct-type-name struct-type-symbol
    struct-type-field-names struct-constructor struct-predicate
    struct-field-accessor struct-field-mutator struct? struct-rtd
    set-rtd-printer!
    (rename (struct-rtd struct-type-descriptor))
    struct-name struct-printer struct-length struct-ref struct-set!)

  (import
    (ikarus system $structs)
    (ikarus system $pairs)
    (ikarus system $fx)
    (except (ikarus)
      make-struct-type struct-type-name struct-type-symbol
      struct-type-field-names struct-constructor struct-predicate
      struct-field-accessor struct-field-mutator struct? struct-rtd
      struct-type-descriptor struct-name struct-printer struct-length
      struct-ref struct-set! set-rtd-printer!))



  (define rtd?
    (lambda (x)
      (and ($struct? x)
           (eq? ($struct-rtd x) (base-rtd)))))

  (define rtd-name
    (lambda (rtd)
      ($struct-ref rtd 0)))

  (define rtd-length
    (lambda (rtd)
      ($struct-ref rtd 1)))

  (define rtd-fields
    (lambda (rtd)
      ($struct-ref rtd 2)))

  (define rtd-printer
    (lambda (rtd)
      ($struct-ref rtd 3)))

  (define rtd-symbol
    (lambda (rtd)
      ($struct-ref rtd 4)))

  (define set-rtd-name!
    (lambda (rtd name)
      ($struct-set! rtd 0 name)))
 
  (define set-rtd-length!
    (lambda (rtd n)
      ($struct-set! rtd 1 n)))

  (define set-rtd-fields!
    (lambda (rtd fields)
      ($struct-set! rtd 2 fields)))

  (define $set-rtd-printer!
    (lambda (rtd printer)
      ($struct-set! rtd 3 printer)))
   
  (define set-rtd-symbol!
    (lambda (rtd symbol)
      ($struct-set! rtd 4 symbol)))

  (define make-rtd
    (lambda (name fields printer symbol)
      ($struct (base-rtd) name (length fields) fields printer symbol)))

  (define verify-field
    (lambda (x)
      (unless (symbol? x) 
        (error 'make-struct-type "~s is not a valid field name" x))))
  
  (define set-fields
    (lambda (r f* i n)
      (cond
        [(null? f*)
         (if ($fx= i n)
             r
             #f)]
        [($fx< i n)
         (if (null? f*)
             #f
             (begin
               ($struct-set! r i ($car f*))
               (set-fields r ($cdr f*) ($fxadd1 i) n)))]
        [else #f])))

  (define make-struct-type
    (case-lambda
      [(name fields)
       (unless (string? name)
         (error 'make-struct-type "name must be a string, got ~s" name))
       (unless (list? fields)
         (error 'make-struct-type "fields must be a list, got ~s" fields))
       (for-each verify-field fields)
       (let ([g (gensym name)])
         (let ([rtd (make-rtd name fields #f g)])
           (set-symbol-value! g rtd)
           rtd))]
      [(name fields g)
       (unless (string? name)
         (error 'make-struct-type "name must be a string, got ~s" name))
       (unless (list? fields)
         (error 'make-struct-type "fields must be a list, got ~s" fields))
       (for-each verify-field fields)
       (cond
         [(symbol-bound? g)
          (let ([rtd (symbol-value g)])
            (unless (and (string=? name (struct-type-name rtd))
                         (equal? fields (struct-type-field-names rtd)))
              (error 'make-struct-type "definition mismatch"))
            rtd)]
         [else
          (let ([rtd (make-rtd name fields #f g)])
            (set-symbol-value! g rtd)
            rtd)])]))

  (define struct-type-name
    (lambda (rtd)
      (unless (rtd? rtd)
        (error 'struct-type-name "~s is not an rtd" rtd))
      (rtd-name rtd)))

  (define struct-type-symbol
    (lambda (rtd)
      (unless (rtd? rtd)
        (error 'struct-type-symbol "~s is not an rtd" rtd))
      (rtd-symbol rtd)))
  
  (define struct-type-field-names
    (lambda (rtd)
      (unless (rtd? rtd)
        (error 'struct-type-field-names "~s is not an rtd" rtd))
      (rtd-fields rtd)))
 

  (define struct-constructor
    (lambda (rtd)
      (unless (rtd? rtd)
        (error 'struct-constructor "~s is not an rtd"))
      (lambda args
        (let ([n (rtd-length rtd)])
          (let ([r ($make-struct rtd n)])
            (or (set-fields r args 0 n)
                (error 'struct-constructor 
                  "incorrect number of arguments to the constructor of ~s" 
                  rtd)))))))
  
  (define struct-predicate
    (lambda (rtd)
      (unless (rtd? rtd)
        (error 'struct-predicate "~s is not an rtd"))
      (lambda (x)
        (and ($struct? x)
             (eq? ($struct-rtd x) rtd)))))

  (define field-index 
    (lambda (i rtd who)
      (cond
        [(fixnum? i)
         (unless (and ($fx>= i 0) ($fx< i (rtd-length rtd)))
           (error who "~s is out of range for rtd ~s" rtd))
         i]
        [(symbol? i)
         (letrec ([lookup
                   (lambda (n ls)
                     (cond
                       [(null? ls) 
                        (error who "~s is not a field in ~s" rtd)]
                       [(eq? i ($car ls)) n]
                       [else (lookup ($fx+ n 1) ($cdr ls))]))])
           (lookup 0 (rtd-fields rtd)))]
        [else (error who "~s is not a valid index" i)])))

  (define struct-field-accessor
    (lambda (rtd i)
      (unless (rtd? rtd)
        (error 'struct-field-accessor "~s is not an rtd" rtd))
      (let ([i (field-index i rtd 'struct-field-accessor)])
        (lambda (x)
          (unless (and ($struct? x) 
                       (eq? ($struct-rtd x) rtd))
            (error 'struct-field-accessor "~s is not of type ~s" x rtd))
          ($struct-ref x i)))))

  (define struct-field-mutator
    (lambda (rtd i)
      (unless (rtd? rtd)
        (error 'struct-field-mutator "~s is not an rtd" rtd))
      (let ([i (field-index i rtd 'struct-field-mutator)])
        (lambda (x v)
          (unless (and ($struct? x) 
                       (eq? ($struct-rtd x) rtd))
            (error 'struct-field-mutator "~s is not of type ~s" x rtd))
          ($struct-set! x i v)))))

  (define struct?
    (lambda (x . rest)
      (if (null? rest)
          ($struct? x)
          (let ([rtd ($car rest)])
            (unless (null? ($cdr rest))
              (error 'struct? "too many arguments"))
            (unless (rtd? rtd)
              (error 'struct? "~s is not an rtd"))
            (and ($struct? x)
                 (eq? ($struct-rtd x) rtd))))))

  (define struct-rtd
    (lambda (x)
      (if ($struct? x)
          ($struct-rtd x)
          (error 'struct-rtd "~s is not a struct" x))))

  (define struct-length
    (lambda (x)
      (if ($struct? x)
          (rtd-length ($struct-rtd x))
          (error 'struct-length "~s is not a struct" x))))
            
  (define struct-name
    (lambda (x)
      (if ($struct? x)
          (rtd-name ($struct-rtd x))
          (error 'struct-name "~s is not a struct" x))))

  (define struct-printer
    (lambda (x)
      (if ($struct? x)
          (rtd-printer ($struct-rtd x))
          (error 'struct-printer "~s is not a struct" x))))

  (define struct-ref
    (lambda (x i)
      (unless ($struct? x) (error 'struct-ref "~s is not a struct" x))
      (unless (fixnum? i) (error 'struct-ref "~s is not a valid index" i))
      (let ([n (rtd-length ($struct-rtd x))])
        (unless (and ($fx>= i 0) ($fx< i n))
          (error 'struct-ref "index ~s is out of range for ~s" i x))
        ($struct-ref x i))))

  (define struct-set!
    (lambda (x i v)
      (unless ($struct? x) (error 'struct-set! "~s is not a struct" x))
      (unless (fixnum? i) (error 'struct-set! "~s is not a valid index" i))
      (let ([n (rtd-length ($struct-rtd x))])
        (unless (and ($fx>= i 0) ($fx< i n))
          (error 'struct-set! "index ~s is out of range for ~s" i x))
        ($struct-set! x i v))))

  (define (set-rtd-printer! x p)
    (unless (rtd? x)
      (error 'set-rtd-printer! "~s is not an rtd" x))
    (unless (procedure? p)
      (error 'set-rtd-printer! "~s is not a procedure" p))
    ($set-rtd-printer! x p))

  (set-rtd-fields! (base-rtd) '(name fields length printer symbol))
  (set-rtd-name! (base-rtd) "base-rtd")
  ($set-rtd-printer! (base-rtd)
    (lambda (x p)
      (unless (rtd? x)
        (error 'struct-type-printer "not an rtd"))
      (display "#<" p)
      (display (rtd-name x) p)
      (display " rtd>" p)))
  )