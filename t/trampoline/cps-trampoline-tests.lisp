(in-package :cl-cc/cps/trampoline/test)

(defun %trampoline-form-contains-p (form sym)
  (cond ((eq form sym) t)
        ((consp form) (or (%trampoline-form-contains-p (car form) sym)
                          (%trampoline-form-contains-p (cdr form) sym)))
        (t nil)))

(it-sequential "cps-sexp-transform-emits-trampoline-thunk"
  (expect (%trampoline-form-contains-p (cl-cc/cps/transform:cps-transform '(+ 1 2))
                                      :cps-trampoline-thunk) :to-be-truthy))

(it-sequential "cps-trampoline-run-forces-tail-thunks"
  (let ((thunk (cl-cc/cps/trampoline::make-cps-trampoline-thunk
                :function (lambda ()
                            (cl-cc/cps/trampoline::make-cps-trampoline-thunk
                             :function (lambda () 42))))))
    (expect (= 42 (cl-cc/cps/trampoline:cps-trampoline-run thunk)) :to-be-truthy)))

(it-sequential "cps-trampoline-form-wraps-tail-continuation-lambda"
  (let ((result (cl-cc/cps/trampoline:cps-trampoline-form '(lambda (v) (funcall k v)))))
    (expect (first result) :to-be 'lambda)
    (expect (%trampoline-form-contains-p result :cps-trampoline-thunk) :to-be-truthy)))
