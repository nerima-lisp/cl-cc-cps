(in-package :cl-cc/cps/transform)

;;; S-Expression Based CPS Transformation (Minimal Bootstrap)
;;;
;;; Handles a small subset of CL sufficient for bootstrapping:
;;; integers, symbols, arithmetic (+/-/*), if, progn, let, print.

(defun %cps-sexp-binop (op a b k)
  "CPS-transform (OP A B) — evaluates A then B, applies OP, passes result to K."
  (let ((va (gensym "A"))
        (vb (gensym "B")))
    (%cps-sexp-node a
      (list 'lambda (list va)
            (%cps-sexp-node b
                            (list 'lambda (list vb)
                                  (list 'funcall k (list op va vb))))))))

(defun %cps-sexp-progn (forms k)
  "CPS-transform a sequence of forms, passing only the last result to K."
  (if (null (cdr forms))
      (%cps-sexp-node (car forms) k)
      (let ((tmp (gensym "TMP")))
        (%cps-sexp-node (car forms)
          (list 'lambda (list tmp)
                (list 'declare (list 'ignore tmp))
                (%cps-sexp-progn (cdr forms) k))))))

(defun %cps-sexp-let-bindings (bindings body k)
  "CPS-transform LET bindings left-to-right, then execute BODY with continuation K."
  (if (null bindings)
      (%cps-sexp-node body k)
      (let* ((sym (first  (car bindings)))
             (val (second (car bindings)))
             (tmp (gensym (symbol-name sym))))
        (%cps-sexp-node val
          (list 'lambda (list tmp)
                (list 'let (list (list sym tmp))
                      (%cps-sexp-let-bindings (cdr bindings) body k)))))))

(defun %cps-falsep (value) "Return true when VALUE is false under Common Lisp truth semantics.\n\nOnly NIL is false; all other values, including numeric zero, are true." (null value))

(defun %cps-sexp-if (node k)
  "CPS-transform an IF form represented by NODE."
  (let ((v (gensym "COND")))
    (%cps-sexp-node (second node)
      (list 'lambda (list v)
            (list 'if (list '%cps-falsep v)
                  (%cps-sexp-node (fourth node) k)
                  (%cps-sexp-node (third node) k))))))

(defun %cps-sexp-print (node k)
  "CPS-transform a PRINT form represented by NODE."
  (let ((v (gensym "PRINT")))
    (%cps-sexp-node (second node)
      (list 'lambda (list v)
            (list 'print v)
            (list 'funcall k v)))))

;;; Adapter functions: bridge the (node k) calling convention to each
;;; implementation function's own argument shape.

(defun %cps-sexp-binop-adapter (node k)
  (%cps-sexp-binop (car node) (second node) (third node) k))

(defun %cps-sexp-progn-adapter (node k)
  (%cps-sexp-progn (cdr node) k))

(defun %cps-sexp-let-adapter (node k)
  (%cps-sexp-let-bindings (second node)
                          (cons 'progn (cddr node))
                          k))

;;; Dispatch table: maps each recognised special form / operator to its adapter.
;;; if and print share the (node k) signature with their impl fns — no adapter needed.

(defun %make-cps-sexp-dispatch-table ()
  "Build the bootstrap CPS dispatch table at load time.

Keeping the source spec local here avoids carrying a second global spec object at
runtime while preserving the data-driven dispatch shape."
  (let ((table (make-hash-table :test 'eq)))
    (dolist (spec '((+     . %cps-sexp-binop-adapter)
                    (-     . %cps-sexp-binop-adapter)
                    (*     . %cps-sexp-binop-adapter)
                    (if    . %cps-sexp-if)
                    (progn . %cps-sexp-progn-adapter)
                    (let   . %cps-sexp-let-adapter)
                    (print . %cps-sexp-print))
                  table)
      (setf (gethash (car spec) table)
            (symbol-function (cdr spec))))))

(defparameter *cps-sexp-dispatch-table*
  (load-time-value (%make-cps-sexp-dispatch-table))
  "Hash table mapping bootstrap CPS special forms/operators to handler functions.")

(defun %cps-sexp-node (node k)
  "CPS-transform a single bootstrap S-expression NODE with continuation K."
  (cond
    ((numberp node) (list 'funcall k node))
    ((symbolp  node) (list 'funcall k node))
    ((consp node)
     (let ((handler (gethash (car node) *cps-sexp-dispatch-table*)))
       (if handler
           (funcall handler node k)
           (error "Unsupported form in CPS: ~S" (car node)))))
    (t
      (error "Unsupported node in CPS: ~S" node))))

(defun cps-transform (expr)
  "Minimal CPS conversion for bootstrap language. Produces (lambda (k) ...).
The outer continuation parameter is always named K for inspection and tests."
  (let ((body (cps-trampoline-form (%cps-sexp-node expr 'k))))
    (cps-simplify-form (list 'lambda '(k) (%cps-wrap-trampoline-run body)))))
