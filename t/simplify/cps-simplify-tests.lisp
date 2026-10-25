(in-package :cl-cc/cps/simplify/test)

(it-sequential "cps-simplify-fixed-point-stops-on-stable-form"
  (let ((calls 0))
    (expect (cl-cc/cps/simplify::%cps-simplify-fixed-point
                   'start
                   (lambda (form)
                     (declare (ignore form))
                     (incf calls)
                     'done)) :to-equal 'done)
    (expect (= 2 calls) :to-be-truthy)))

(it-sequential "cps-simplify-form-reductions eta-reduce"
  (destructuring-bind (expected form) (list 'next '(lambda (k) (funcall next k)))
    (expect (cl-cc/cps/simplify:cps-simplify-form form) :to-equal expected)))

(it-sequential "cps-simplify-form-reductions beta-reduce"
  (destructuring-bind (expected form) (list 42 '(funcall (lambda (x) x) 42))
    (expect (cl-cc/cps/simplify:cps-simplify-form form) :to-equal expected)))

(it-sequential "cps-simplify-walk-nested-reduction"
  (let* ((inner '(funcall (lambda (x) x) 99))
         (outer (list inner 1 2))
         (result (cl-cc/cps/simplify::%cps-simplify-walk outer)))
    (expect (first result) :to-equal 99)))

(it-sequential "cps-simplify-walk-eta-reduces"
  (expect (cl-cc/cps/simplify::%cps-simplify-walk '(lambda (k) (funcall f k))) :to-equal 'f))

(it-sequential "cps-simplify-walk-beta-reduces"
  (expect (cl-cc/cps/simplify::%cps-simplify-walk '(funcall (lambda (x) x) 42)) :to-equal 42))

(it-sequential "cps-simplify-walk-atom-passthrough keyword"
  (destructuring-bind (expected input) (list :hello :hello)
    (expect (cl-cc/cps/simplify::%cps-simplify-walk input) :to-equal expected)))

(it-sequential "cps-simplify-walk-atom-passthrough nil"
  (destructuring-bind (expected input) (list nil nil)
    (expect (cl-cc/cps/simplify::%cps-simplify-walk input) :to-equal expected)))

(it-sequential "cps-simplify-walk-atom-passthrough symbol"
  (destructuring-bind (expected input) (list 'foo 'foo)
    (expect (cl-cc/cps/simplify::%cps-simplify-walk input) :to-equal expected)))

(it-sequential "cps-simplify-walk-atom-passthrough number"
  (destructuring-bind (expected input) (list 42 42)
    (expect (cl-cc/cps/simplify::%cps-simplify-walk input) :to-equal expected)))

(it-sequential "cps-eta-reducible-lambda-p no-multi-param"
  (destructuring-bind (expected form) (list nil '(lambda (k j) (funcall next k)))
    (expect (cl-cc/cps/simplify::%eta-reducible-lambda-p form) :to-equal expected)))

(it-sequential "cps-eta-reducible-lambda-p no-plain-lambda"
  (destructuring-bind (expected form) (list nil '(lambda (k) k))
    (expect (cl-cc/cps/simplify::%eta-reducible-lambda-p form) :to-equal expected)))

(it-sequential "cps-eta-reducible-lambda-p no-extra-body"
  (destructuring-bind (expected form) (list nil '(lambda (k) (print k) (funcall next k)))
    (expect (cl-cc/cps/simplify::%eta-reducible-lambda-p form) :to-equal expected)))

(it-sequential "cps-eta-reducible-lambda-p no-wrong-param"
  (destructuring-bind (expected form) (list nil '(lambda (k) (funcall next x)))
    (expect (cl-cc/cps/simplify::%eta-reducible-lambda-p form) :to-equal expected)))

(it-sequential "cps-eta-reducible-lambda-p yes"
  (destructuring-bind (expected form) (list t '(lambda (k) (funcall next k)))
    (expect (cl-cc/cps/simplify::%eta-reducible-lambda-p form) :to-equal expected)))

(it-sequential "cps-funcall-single-lambda-parts"
  (multiple-value-bind (param body arg)
      (cl-cc/cps/simplify::%funcall-single-lambda-parts '(funcall (lambda (x) (+ x 1)) 41))
    (expect param :to-be 'x)
    (expect body :to-equal '(+ x 1))
    (expect (= 41 arg) :to-be-truthy)))

(it-sequential "cps-single-param-lambda-parts"
  (multiple-value-bind (param body)
      (cl-cc/cps/simplify::%single-param-lambda-parts '(lambda (k) (funcall next k)))
    (expect param :to-be 'k)
    (expect body :to-equal '(funcall next k))))

(it-sequential "cps-funcall-of-single-lambda-p no-atom"
  (destructuring-bind (expected form) (list nil 42)
    (expect (cl-cc/cps/simplify::%funcall-of-single-lambda-p form) :to-equal expected)))

(it-sequential "cps-funcall-of-single-lambda-p no-multi-param"
  (destructuring-bind (expected form) (list nil '(funcall (lambda (x y) x) 1))
    (expect (cl-cc/cps/simplify::%funcall-of-single-lambda-p form) :to-equal expected)))

(it-sequential "cps-funcall-of-single-lambda-p no-plain-fn"
  (destructuring-bind (expected form) (list nil '(funcall f 42))
    (expect (cl-cc/cps/simplify::%funcall-of-single-lambda-p form) :to-equal expected)))

(it-sequential "cps-funcall-of-single-lambda-p no-multi-args"
  (destructuring-bind (expected form) (list nil '(funcall (lambda (x) x) 1 2))
    (expect (cl-cc/cps/simplify::%funcall-of-single-lambda-p form) :to-equal expected)))

(it-sequential "cps-funcall-of-single-lambda-p yes"
  (destructuring-bind (expected form) (list t '(funcall (lambda (x) x) 42))
    (expect (cl-cc/cps/simplify::%funcall-of-single-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p no-atom"
  (destructuring-bind (expected form) (list nil 42)
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p no-not-lambda"
  (destructuring-bind (expected form) (list nil '(funcall f x))
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p no-zero-param"
  (destructuring-bind (expected form) (list nil '(lambda () 42))
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p no-multi-param"
  (destructuring-bind (expected form) (list nil '(lambda (x y) x))
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p yes-with-body"
  (destructuring-bind (expected form) (list t '(lambda (k) (funcall f k)))
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))

(it-sequential "cps-single-param-lambda-p yes-single"
  (destructuring-bind (expected form) (list t '(lambda (x) x))
    (expect (cl-cc/cps/simplify::%single-param-lambda-p form) :to-equal expected)))
