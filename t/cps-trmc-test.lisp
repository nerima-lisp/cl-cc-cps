;;;; t/cps-trmc-test.lisp — unit tests for the TRMC (Tail Recursion Modulo
;;;; Cons) transformation functions defined in src/cps.lisp.
;;;;
;;;; These tests exercise the transformation functions directly, not via
;;;; run-string or the full compilation pipeline. Ported from the monorepo's
;;;; packages/cps/tests/cps-trmc-tests.lisp (originally written against the
;;;; in-tree deftest/deftest-each framework) to cl-weave's describe-sequential
;;;; / it / it-each / expect.

(in-package :cl-cc-cps/test)

;;; ─────────────────────────────────────────────────────────────────────────
;;; Helpers (local to this suite)
;;; ─────────────────────────────────────────────────────────────────────────

(defun %trmc-contains-p (form sym)
  "Return T if SYM appears anywhere in FORM (recursive tree walk)."
  (cond ((eq form sym) t)
        ((consp form) (or (%trmc-contains-p (car form) sym)
                          (%trmc-contains-p (cdr form) sym)))
        (t nil)))

(defun %trmc-rewritten-p (source rewritten)
  "Return T when REWRITTEN has the accumulator-worker shape expected of TRMC output."
  (and (not (equal source rewritten))
       (%trmc-contains-p rewritten 'labels)
       (or (%trmc-contains-p rewritten 'nreverse)
           (%trmc-contains-p rewritten 'nreconc))))

(describe-sequential "TRMC transformation"
  (it "rewrites a simple cons tail-recursive pattern into a labels/accumulator worker"
    (let* ((source '(defun trmc-simple (n)
                     (if (zerop n)
                         nil
                         (cons n (trmc-simple (1- n))))))
           (rewritten (cl-cc/cps::trmc-transform-defun-form source)))
      ;; The output must differ from the input and carry the accumulator shape.
      (expect (%trmc-rewritten-p source rewritten) :to-be-truthy)
      ;; The rewritten form is still a DEFUN with the same name.
      (expect (first rewritten) :to-equal 'defun)
      (expect (second rewritten) :to-equal 'trmc-simple)
      ;; Evaluating and calling the rewritten function gives the correct result.
      (eval rewritten)
      (expect (funcall (symbol-function 'trmc-simple) 3) :to-equal '(3 2 1))))

  (it "leaves pure tail recursion (no cons) untransformed"
    (let* ((source '(defun trmc-sum (n acc)
                     (if (zerop n)
                         acc
                         (trmc-sum (1- n) (+ acc n)))))
           (rewritten (cl-cc/cps::trmc-transform-defun-form source)))
      ;; No TRMC pattern found — form is returned unchanged.
      (expect rewritten :to-equal source)
      ;; Sanity-check: no labels injected.
      (expect (%trmc-contains-p rewritten 'labels) :to-be nil)))

  (it "handles a multi-head cons chain, e.g. (cons a (cons b (self ...)))"
    (let* ((source '(defun trmc-two-heads (n)
                     (if (zerop n)
                         nil
                         (cons n (cons (- n) (trmc-two-heads (1- n)))))))
           (rewritten (cl-cc/cps::trmc-transform-defun-form source)))
      (expect (%trmc-rewritten-p source rewritten) :to-be-truthy)
      ;; Running the rewritten function produces the right flat list.
      (eval rewritten)
      (expect (funcall (symbol-function 'trmc-two-heads) 2) :to-equal '(2 -2 1 -1))))

  (it "is idempotent: applying the transform twice gives the same result"
    (let* ((source '(defun trmc-idem (n)
                     (if (zerop n)
                         nil
                         (cons n (trmc-idem (1- n))))))
           (once   (cl-cc/cps::trmc-transform-defun-form source))
           (twice  (cl-cc/cps::trmc-transform-defun-form once)))
      ;; The first application transforms the form.
      (expect (%trmc-rewritten-p source once) :to-be-truthy)
      ;; The second application must not alter the already-transformed form.
      ;; After the first pass the self-recursive call is to the worker gensym,
      ;; which does not match the outer name, so the pass is a no-op.
      (expect twice :to-equal once)))

  (it "is a no-op when *enable-trmc* is nil"
    (let ((source '(defun trmc-disabled (n)
                    (if (zerop n)
                        nil
                        (cons n (trmc-disabled (1- n)))))))
      (let ((cl-cc/cps:*enable-trmc* nil))
        (expect (cl-cc/cps::trmc-transform-defun-form source) :to-equal source))))

  ;; The guard in trmc-transform-defun-form is (every #'symbolp lambda-list).
  ;; Lambda-list elements that are lists (default forms) cause the guard to
  ;; fire, leaving the form untouched. Also covers non-defun forms.
  (it-each
      (("optional-with-default"
        '(defun trmc-opt (n &optional (acc nil))
          (if (zerop n)
              acc
              (cons n (trmc-opt (1- n))))))

       ("key-with-default"
        '(defun trmc-key (n &key (step 1))
          (if (zerop n)
              nil
              (cons n (trmc-key (- n step))))))

       ("not-a-defun"
        '(defmacro trmc-mac (n)
          `(cons ,n (trmc-mac (1- ,n))))))
      "leaves ~A unchanged (non-simple lambda-list or non-defun)"
      (label source)
    (declare (ignore label))
    (expect (cl-cc/cps::trmc-transform-defun-form source) :to-equal source)))
