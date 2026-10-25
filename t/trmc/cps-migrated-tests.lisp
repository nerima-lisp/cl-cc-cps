(in-package :cl-cc/cps/trmc/test)

(defun %eval-trmc-defun (form symbol)
  (eval form)
  (symbol-function symbol))

(it-sequential "cps-trmc-host-native-compiled-worker-produces-correct-result"
  (let* ((source '(defun trmc-native-fixture (n)
                   (if (<= n 0)
                       nil
                       (cons n (trmc-native-fixture (- n 1))))))
         (rewritten (cl-cc/cps/trmc:trmc-transform-defun-form source)))
    (expect (%trmc-rewritten-p source rewritten) :to-be-truthy)
    (eval rewritten)
    (compile 'trmc-native-fixture)
    (expect (funcall (symbol-function 'trmc-native-fixture) 5) :to-equal '(5 4 3 2 1))))

(it-sequential "cps-trmc-rewrites-let-and-let-star-wrapper-tail-cons"
  (let* ((let-source '(defun trmc-let-wrapper (n)
                       (if (<= n 0)
                           nil
                           (let ((x n))
                             (cons x (trmc-let-wrapper (- n 1)))))))
         (let*-source '(defun trmc-let-star-wrapper (n)
                         (if (<= n 0)
                             nil
                             (let* ((x n)
                                    (y (+ x 10)))
                               (cons y (trmc-let-star-wrapper (- n 1)))))))
         (let-rewritten (cl-cc/cps/trmc:trmc-transform-defun-form let-source))
         (let*-rewritten (cl-cc/cps/trmc:trmc-transform-defun-form let*-source)))
    (expect (%trmc-rewritten-p let-source let-rewritten) :to-be-truthy)
    (expect (%trmc-rewritten-p let*-source let*-rewritten) :to-be-truthy)
    (expect (funcall (%eval-trmc-defun let-rewritten 'trmc-let-wrapper) 3) :to-equal '(3 2 1))
    (expect (funcall (%eval-trmc-defun let*-rewritten 'trmc-let-star-wrapper) 3) :to-equal '(13 12 11))))

(it-sequential "cps-trmc-rewrites-block-wrapper-tail-cons"
  (let* ((source '(defun trmc-block-wrapper (n)
                   (if (<= n 0)
                       nil
                       (block nil
                         (cons n (trmc-block-wrapper (- n 1)))))))
         (rewritten (cl-cc/cps/trmc:trmc-transform-defun-form source)))
    (expect (%trmc-rewritten-p source rewritten) :to-be-truthy)
    (expect (funcall (%eval-trmc-defun rewritten 'trmc-block-wrapper) 4) :to-equal '(4 3 2 1))))

(it-sequential "cps-trmc-rewrites-nested-if-tail-cons-branches"
  (let* ((source '(defun trmc-nested-if (n p)
                   (if (<= n 0)
                       nil
                       (if p
                           (cons :a (trmc-nested-if (- n 1) nil))
                           (cons :b (trmc-nested-if (- n 1) t))))))
         (rewritten (cl-cc/cps/trmc:trmc-transform-defun-form source)))
    (expect (%trmc-rewritten-p source rewritten) :to-be-truthy)
    (expect (funcall (%eval-trmc-defun rewritten 'trmc-nested-if) 4 t) :to-equal '(:a :b :a :b))))

(it-sequential "cps-trmc-does-not-rewrite-nonrecursive-dotted-base"
  (let* ((source '(defun trmc-dotted-base ()
                   (cons 'a '(b . c))))
         (rewritten (cl-cc/cps/trmc:trmc-transform-defun-form source)))
    (expect rewritten :to-equal source)
    (expect (funcall (%eval-trmc-defun rewritten 'trmc-dotted-base)) :to-equal '(a b . c))))

(it-sequential "cps-trmc-rewrites-obvious-self-recursive-cons"
  (let* ((source '(defun trmc-fixture (n)
                   (if (<= n 0)
                       nil
                       (cons n (trmc-fixture (- n 1))))))
         (rewritten (cl-cc/cps/trmc:trmc-transform-defun-form source)))
    (expect (equal source rewritten) :to-be-falsy)
    (expect (%trmc-contains-p rewritten 'labels) :to-be-truthy)
    (eval rewritten)
    (expect (funcall (symbol-function 'trmc-fixture) 3) :to-equal '(3 2 1))))
