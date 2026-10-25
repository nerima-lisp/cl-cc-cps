(in-package :cl-cc/cps/simplify)

;;; CPS simplification helpers live here because the bootstrap transform depends
;;; on them immediately, and keeping them contiguous avoids hidden load-order
;;; coupling in the compile subsystem.

(defun %cps-simplify-subtree (tree var replacement)
  (cond
    ((eq tree var) replacement)
    ((consp tree)
     (cons (%cps-simplify-subtree (car tree) var replacement)
           (%cps-simplify-subtree (cdr tree) var replacement)))
    (t tree)))

(defun %single-param-lambda-parts (form)
  "Return (values param body) when FORM is a one-argument lambda, else NIL values."
  (when (and (consp form)
             (eq (car form) 'lambda)
             (let ((params (second form)))
               (and (consp params) (null (cdr params))))
             (= (length form) 3))
    (values (first (second form))
            (third form))))

(defun %single-param-lambda-p (form)
  "T if FORM is (lambda (x) body) with exactly one parameter."
  (multiple-value-bind (param body)
      (%single-param-lambda-parts form)
    (declare (ignore body))
    (not (null param))))

(defun %funcall-single-lambda-parts (form)
  "Return (values param body arg) when FORM is a beta-reducible funcall, else NIL values."
  (when (and (consp form)
             (eq (car form) 'funcall)
             (not (null (cddr form)))
             (null (cdddr form)))
    (multiple-value-bind (param body)
        (%single-param-lambda-parts (second form))
      (when param
        (values param body (third form))))))

(defun %funcall-of-single-lambda-p (form)
  "T if FORM is (funcall (lambda (x) body) arg) — beta-reducible."
  (multiple-value-bind (param body arg)
      (%funcall-single-lambda-parts form)
    (declare (ignore body arg))
    (not (null param))))

(defun %eta-reducible-lambda-p (form)
  "T if FORM is (lambda (x) (funcall f x)) — eta-reducible."
  (multiple-value-bind (param body)
      (%single-param-lambda-parts form)
    (and param
         (consp body)
         (eq (car body) 'funcall)
         (consp (cddr body))
         (null (cdddr body))
         (eq (third body) param))))

(defun %cps-beta-reduce (form)
  "Beta-reduce (funcall (lambda (x) body) arg) → body[x/arg]."
  (multiple-value-bind (param body arg)
      (%funcall-single-lambda-parts form)
    (if param
        (%cps-simplify-subtree body param arg)
        form)))

(defun %cps-eta-reduce (form)
  "Eta-reduce (lambda (x) (funcall f x)) → f."
  (if (%eta-reducible-lambda-p form)
      (second (third form))
      form))

(defun %cps-simplify-walk (x)
  "Recursively apply beta/eta reduction bottom-up to sexp X."
  (if (consp x)
      (%cps-eta-reduce
       (%cps-beta-reduce
        (mapcar #'%cps-simplify-walk x)))
      x))

(defun %cps-simplify-fixed-point (form step-fn)
  "Apply STEP-FN to FORM until a fixed point is reached."
  (loop
    for current = form then next
    for next = (funcall step-fn current)
    until (equal current next)
    finally (return current)))

(defun cps-simplify-form (form)
  "Repeatedly simplify FORM until a fixed point is reached."
  (%cps-simplify-fixed-point form #'%cps-simplify-walk))
