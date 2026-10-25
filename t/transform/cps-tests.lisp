;;;; CPS transformation tests
;;;;
;;;; Defines helpers shared with CPS AST tests.
;;;; Covers semantic tests for the S-expression bootstrap transformer.

(in-package :cl-cc/cps/transform/test)


;;; ─────────────────────────────────────────────────────────────────────────
;;; Helpers
;;; ─────────────────────────────────────────────────────────────────────────

(defun eval-cps-ast (ast)
  "CPS-transform an AST node to a (lambda (k) ...) sexp and evaluate it.
Returns a function that takes a continuation."
  (eval (cl-cc/cps/transform:cps-transform-ast* ast)))

(defun run-cps-ast (ast)
  "Run CPS-transformed AST with the identity continuation."
  (funcall (eval-cps-ast ast) #'identity))

(defun is-cps-lambda (result)
  "Return t if RESULT is a (lambda (k) ...) sexp as produced by cps-transform-ast*."
  (and (listp result)
       (eq 'lambda (car result))))

(defun %cps-form-contains-p (form sym)
  "Return T if SYM appears anywhere in FORM."
  (cond ((eq form sym) t)
        ((consp form) (or (%cps-form-contains-p (car form) sym)
                          (%cps-form-contains-p (cdr form) sym)))
        (t nil)))

(defun %cps-trmc-rewritten-p (source rewritten)
  "Return T when REWRITTEN has the expected accumulator-worker TRMC shape."
  (and (not (equal source rewritten))
       (%cps-form-contains-p rewritten 'labels)
       (or (%cps-form-contains-p rewritten 'nreverse)
           (%cps-form-contains-p rewritten 'nreconc))))

(defun %eval-trmc-defun (form symbol)
  "Evaluate FORM and return SYMBOL's function object."
  (eval form)
  (symbol-function symbol))

;;; ─────────────────────────────────────────────────────────────────────────
;;; S-expression CPS (bootstrap transformer)
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "cps-sexp-transform integer"
  (destructuring-bind (expr expected) (list '42 42)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform add"
  (destructuring-bind (expr expected) (list '(+ 1 2) 3)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform sub"
  (destructuring-bind (expr expected) (list '(- 10 3) 7)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform mul"
  (destructuring-bind (expr expected) (list '(* 3 4) 12)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform if-true"
  (destructuring-bind (expr expected) (list '(if 1 10 20) 10)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform if-false"
  (destructuring-bind (expr expected) (list '(if nil 10 20) 20)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform progn-returns-last"
  (destructuring-bind (expr expected) (list '(progn 1 2 3) 3)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform let-binding"
  (destructuring-bind (expr expected) (list '(let ((x 1) (y 2)) (+ x y)) 3)
    (let ((fn (cl-cc/cps/transform:cps-transform-eval expr)))
    (expect (funcall fn #'identity) :to-equal expected))))

(it-sequential "cps-sexp-transform-emits-trampoline-thunk"
  (expect (%cps-form-contains-p (cl-cc/cps/transform:cps-transform '(+ 1 2))
                                      :cps-trampoline-thunk) :to-be-truthy))

