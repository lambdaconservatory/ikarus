
(library (ikarus fixnums)
  (export fxzero? fxadd1 fxsub1 fxlognot fx+ fx- fx* fxquotient
          fx+/carry fx*/carry fx-/carry
          fxremainder fxmodulo fxlogor fxlogand fxlogxor fxsll fxsra
          fx= fx< fx<= fx> fx>= 
          fx=? fx<? fx<=? fx>? fx>=? 
          fxior fxand fxxor fxnot fxif
          fxpositive? fxnegative?
          fxeven? fxodd?
          fixnum->string 
          fxarithmetic-shift-left fxarithmetic-shift-right fxarithmetic-shift
          fxmin fxmax
          error@fx+)
  (import 
    (ikarus system $fx)
    (ikarus system $chars)
    (ikarus system $pairs)
    (ikarus system $strings)
    (prefix (only (ikarus) fx+) sys:)
    (except (ikarus) fxzero? fxadd1 fxsub1 fxlognot fx+ fx- fx*
            fxquotient fxremainder fxmodulo fxlogor fxlogand
            fxlogxor fxsll fxsra fx= fx< fx<= fx> fx>=
            fx=? fx<? fx<=? fx>? fx>=? 
            fxior fxand fxxor fxnot fxif
            fxpositive? fxnegative?
            fxeven? fxodd?
            fxarithmetic-shift-left fxarithmetic-shift-right fxarithmetic-shift
            fx+/carry fx*/carry fx-/carry
            fxmin fxmax
            fixnum->string))

  (define fxzero?
    (lambda (x)
      (cond
        [(eq? x 0) #t]
        [(fixnum? x) #f]
        [else (error 'fxzero? "~s is not a fixnum" x)])))
  
  (define fxadd1
    (lambda (n)
      (if (fixnum? n)
          ($fxadd1 n)
          (error 'fxadd1 "~s is not a fixnum" n))))
  
  (define fxsub1 
    (lambda (n) 
      (if (fixnum? n)
          ($fxsub1 n)
          (error 'fxsub1 "~s is not a fixnum" n))))

  (define fxlognot 
    (lambda (x)
      (unless (fixnum? x) 
        (error 'fxlognot "~s is not a fixnum" x))
      ($fxlognot x)))

  (define fxnot 
    (lambda (x)
      (unless (fixnum? x) 
        (error 'fxnot "~s is not a fixnum" x))
      ($fxlognot x)))
  
  (define error@fx+
    (lambda (x y) 
      (if (fixnum? x) 
          (if (fixnum? y) 
              (error 'fx+ "overflow when adding ~s and ~s" x y)
              (error 'fx+ "~s is not a fixnum" y))
          (error 'fx+ "~s is not a fixnum" x))))

  (define fx+ 
    (lambda (x y) 
      (sys:fx+ x y)))

  (define fx-
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fx- "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fx- "~s is not a fixnum" y))
      ($fx- x y)))

  (define fx*
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fx* "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fx* "~s is not a fixnum" y))
      ($fx* x y)))
  

  (define false-loop
    (lambda (who ls)
      (if (pair? ls) 
          (if (fixnum? ($car ls)) 
              (false-loop who ($cdr ls))
              (error who "~s is not a fixnum" ($car ls)))
          #f)))

  (define-syntax fxcmp 
    (syntax-rules ()
      [(_ who $op)
       (case-lambda
         [(x y) 
          (unless (fixnum? x)
            (error 'who "~s is not a fixnum" x))
          (unless (fixnum? y)
            (error 'who "~s is not a fixnum" y))
          ($op x y)]
         [(x y . ls)
          (if (fixnum? x)
              (if (fixnum? y) 
                  (if ($op x y) 
                      (let f ([x y] [ls ls]) 
                        (if (pair? ls) 
                            (let ([y ($car ls)] [ls ($cdr ls)])
                              (if (fixnum? y) 
                                  (if ($op x y) 
                                      (f y ls)
                                      (false-loop 'who ls))
                                  (error 'who "~s is not a fixnum" y)))
                            #t))
                      (false-loop 'who ls))
                  (error 'who "~s is not a fixnum" y))
              (error 'who "~s is not a fixnum" x))]
         [(x) 
          (if (fixnum? x) #t (error 'who "~s is not a fixnum" x))])]))
  
  (define fx=   (fxcmp fx= $fx=))
  (define fx<   (fxcmp fx< $fx<))
  (define fx<=  (fxcmp fx<= $fx<=))
  (define fx>   (fxcmp fx> $fx>))
  (define fx>=  (fxcmp fx>= $fx>=))
  (define fx=?  (fxcmp fx=? $fx=))
  (define fx<?  (fxcmp fx<? $fx<))
  (define fx<=? (fxcmp fx<=? $fx<=))
  (define fx>?  (fxcmp fx>? $fx>))
  (define fx>=? (fxcmp fx>=? $fx>=))


  (define fxquotient
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxquotient "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxquotient "~s is not a fixnum" y))
      (when ($fxzero? y)
        (error 'fxquotient "zero dividend ~s" y))
      ($fxquotient x y))) 
  
  (define fxremainder
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxremainder "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxremainder "~s is not a fixnum" y))
      (when ($fxzero? y)
        (error 'fxremainder "zero dividend ~s" y))
      (let ([q ($fxquotient x y)])
        ($fx- x ($fx* q y)))))
   
  (define fxmodulo
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxmodulo "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxmodulo "~s is not a fixnum" y))
      (when ($fxzero? y)
        (error 'fxmodulo "zero dividend ~s" y))
      ($fxmodulo x y)))

  (define-syntax fxbitop
    (syntax-rules ()
      [(_ who $op identity)
       (case-lambda 
         [(x y) 
          (if (fixnum? x) 
              (if (fixnum? y) 
                  ($op x y)
                  (error 'who "~s is not a fixnum" y))
              (error 'who "~s is not a fixnum" x))]
         [(x y . ls) 
          (if (fixnum? x)
              (if (fixnum? y) 
                  (let f ([a ($op x y)] [ls ls])
                    (cond
                      [(pair? ls) 
                       (let ([b ($car ls)])
                         (if (fixnum? b) 
                             (f ($op a b) ($cdr ls))
                             (error 'who "~s is not a fixnum" b)))]
                      [else a]))
                  (error 'who "~s is not a fixnum" y))
              (error 'who "~s is not a fixnum" x))]
         [(x) (if (fixnum? x) x (error 'who "~s is not a fixnum" x))]
         [()   identity])]))

  (define fxlogor (fxbitop fxlogor $fxlogor 0))
  (define fxlogand (fxbitop fxlogand $fxlogand -1))
  (define fxlogxor (fxbitop fxlogxor $fxlogxor 0))
  (define fxior (fxbitop fxior $fxlogor 0))
  (define fxand (fxbitop fxand $fxlogand -1))
  (define fxxor (fxbitop fxxor $fxlogxor 0))
  
  (define (fxif x y z)
    (if (fixnum? x)
        (if (fixnum? y) 
            (if (fixnum? z) 
                ($fxlogor 
                  ($fxlogand x y) 
                  ($fxlogand ($fxlognot x) z))
                (error 'fxif "~s is not a fixnum" z))
            (error 'fxif "~s is not a fixnum" y))
        (error 'fxif "~s is not a fixnum" x)))

  (define fxsra
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxsra "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxsra "~s is not a fixnum" y))
      (unless ($fx>= y 0)
        (error 'fxsra "negative shift not allowed, got ~s" y))
      ($fxsra x y)))
   

  (define fxarithmetic-shift-right
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxarithmetic-shift-right "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxarithmetic-shift-right "~s is not a fixnum" y))
      (unless ($fx>= y 0)
        (error 'fxarithmetic-shift-right "negative shift not allowed, got ~s" y))
      ($fxsra x y)))

  (define fxsll
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxsll "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxsll "~s is not a fixnum" y))
      (unless ($fx>= y 0)
        (error 'fxsll "negative shift not allowed, got ~s" y))
      ($fxsll x y))) 


  (define fxarithmetic-shift-left
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxarithmetic-shift-left "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxarithmetic-shift-left "~s is not a fixnum" y))
      (unless ($fx>= y 0)
        (error 'fxarithmetic-shift-left "negative shift not allowed, got ~s" y))
      ($fxsll x y)))

  (define fxarithmetic-shift
    (lambda (x y) 
      (unless (fixnum? x)
        (error 'fxarithmetic-shift "~s is not a fixnum" x))
      (unless (fixnum? y)
        (error 'fxarithmetic-shift "~s is not a fixnum" y))
      (if ($fx>= y 0)
          ($fxsll x y)
          (if ($fx< x -100) ;;; arbitrary number < (fixnum-width)
              ($fxsra x 32)
              ($fxsra x ($fx- 0 y))))))

  (define (fxpositive? x)
    (if (fixnum? x) 
        ($fx> x 0)
        (error 'fxpositive? "~s is not a fixnum" x)))

  (define (fxnegative? x)
    (if (fixnum? x) 
        ($fx< x 0)
        (error 'fxnegative? "~s is not a fixnum" x)))
  
  (define (fxeven? x)
    (if (fixnum? x) 
        ($fxzero? ($fxlogand x 1))
        (error 'fxeven? "~s is not a fixnum" x)))

  (define (fxodd? x)
    (if (fixnum? x) 
        (not ($fxzero? ($fxlogand x 1)))
        (error 'fxodd? "~s is not a fixnum" x)))

  (define fxmin
    (case-lambda 
      [(x y) 
       (if (fixnum? x) 
           (if (fixnum? y) 
               (if ($fx< x y) x y)
               (error 'fxmin "~s is not a fixnum" y))
           (error 'fxmin "~s is not a fixnum" x))]
      [(x y z . ls)
       (fxmin (fxmin x y) 
         (if (fixnum? z) 
             (let f ([z z] [ls ls])
               (if (null? ls)
                   z
                   (let ([a ($car ls)])
                     (if (fixnum? a) 
                         (if ($fx< a z) 
                             (f a ($cdr ls))
                             (f z ($cdr ls)))
                         (error 'fxmin "~s is not a fixnum" a)))))
             (error 'fxmin "~s is not a fixnum" z)))]
      [(x) (if (fixnum? x) x (error 'fxmin "~s is not a fixnum" x))]))

  (define fxmax
    (case-lambda 
      [(x y)
       (if (fixnum? x) 
           (if (fixnum? y) 
               (if ($fx> x y) x y)
               (error 'fxmax "~s is not a fixnum" y))
           (error 'fxmax "~s is not a fixnum" x))]
      [(x y z . ls)
       (fxmax (fxmax x y) 
         (if (fixnum? z) 
             (let f ([z z] [ls ls])
               (if (null? ls)
                   z
                   (let ([a ($car ls)])
                     (if (fixnum? a) 
                         (if ($fx> a z)
                             (f a ($cdr ls))
                             (f z ($cdr ls)))
                         (error 'fxmax "~s is not a fixnum" a)))))
             (error 'fxmax "~s is not a fixnum" z)))]
      [(x) (if (fixnum? x) x (error 'fxmax "~s is not a fixnum" x))]))

  (define (fx*/carry fx1 fx2 fx3)
    (let ([s0 ($fx+ ($fx* fx1 fx2) fx3)])
      (values 
        s0
        (sra (+ (* fx1 fx2) (- fx3 s0)) (fixnum-width)))))
  
  (define (fx+/carry fx1 fx2 fx3)
    (let ([s0 ($fx+ ($fx+ fx1 fx2) fx3)])
      (values 
        s0
        (sra (+ (+ fx1 fx2) (- fx3 s0)) (fixnum-width)))))
  
  (define (fx-/carry fx1 fx2 fx3)
    (let ([s0 ($fx- ($fx- fx1 fx2) fx3)])
      (values 
        s0
        (sra (- (- fx1 fx2) (+ s0 fx3)) (fixnum-width)))))

  (module (fixnum->string)
    (define f
      (lambda (n i j)
        (cond
          [($fxzero? n) 
           (values (make-string i) j)]
          [else
           (let ([q ($fxquotient n 10)])
             (call-with-values
               (lambda () (f q ($fxadd1 i) j))
               (lambda (str j)
                 (let ([r ($fx- n ($fx* q 10))])
                   (string-set! str j
                      ($fixnum->char ($fx+ r ($char->fixnum #\0))))
                   (values str ($fxadd1 j))))))])))
    (define fixnum->string
      (lambda (x)
        (unless (fixnum? x) (error 'fixnum->string "~s is not a fixnum" x))
        (cond
          [($fxzero? x) "0"]
          [($fx> x 0) 
           (call-with-values
             (lambda () (f x 0 0))
             (lambda (str j) str))]
          ;;; FIXME: DON'T HARDCODE CONSTANTS
          [($fx= x -536870912) "-536870912"]
          [else
           (call-with-values
             (lambda () (f ($fx- 0 x) 1 1))
             (lambda (str j)
               ($string-set! str 0 #\-)
               str))]))))


  )