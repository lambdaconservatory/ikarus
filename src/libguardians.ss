
(let ()
  (define make-guardian
    (lambda ()
      (let ([tc
             (let ([x (cons #f #f)])
               (cons x x))])
        (case-lambda
          [()
           (and (not (eq? (car tc) (cdr tc)))
                (let ([x (car tc)])
                  (let ([y (car x)])
                    (set-car! tc (cdr x))
                    (set-car! x #f)
                    (set-cdr! x #f)
                    y)))]
          [(obj) 
           (foreign-call "ikrt_register_guardian" tc obj)
           (void)]))))
  (primitive-set! 'make-guardian make-guardian))