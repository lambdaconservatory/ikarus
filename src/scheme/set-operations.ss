

(define (remq1 x ls)
  (cond
    [(null? ls) '()]
    [(eq? x (car ls)) (cdr ls)]
    [else
     (let ([t (remq1 x (cdr ls))])
       (cond
         [(eq? t (cdr ls)) ls]
         [else (cons (car ls) t)]))]))

(define (singleton x) (list x))

(define (union s1 s2)
  (define (add* s1 s2)
    (cond
     [(null? s1) s2]
     [else (add (car s1) (add* (cdr s1) s2))]))
  (define (add x s)
    (cond
     [(memq x s) s]
     [else (cons x s)]))
  (cond
   [(null? s1) s2]
   [(null? s2) s1]
   [else (add* s1 s2)]))

(define (difference s1 s2)
  (define (rem* s1 s2)
    (cond
     [(null? s1) s2]
     [else (remq1 (car s1) (rem* (cdr s1) s2))]))
  (cond
   [(null? s1) '()]
   [(null? s2) s1]
   [else (rem* s2 s1)]))
