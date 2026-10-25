;;;; packages/cps/src/package.lisp — feature package for cl-cc/cps
;;;;
;;;; CPS transformation: continuation-passing style conversion for the
;;;; compilation pipeline. Uses cl-cc/bootstrap and cl-cc/ast so cps
;;;; source files can reference AST node accessors unqualified.
(defpackage :cl-cc/cps
            (:use :cl)
            (:import-from :cl-cc/cps/transform
                          #:cps-transform
                          #:cps-transform*
                          #:cps-transform-ast
                          #:unsupported-cps-ast
                          #:unsupported-cps-ast-node
                          #:unsupported-cps-ast-node-type
                          #:cps-transform-ast*
                          #:cps-transform-sequence
                          #:cps-transform-eval)
            (:import-from :cl-cc/cps/simplify #:cps-simplify-form)
            (:import-from :cl-cc/cps/trampoline #:cps-trampoline-run)
            (:import-from :cl-cc/cps/trmc #:*enable-trmc*)
            (:export #:cps-transform
                     #:cps-transform*
                     #:cps-transform-ast
                     #:unsupported-cps-ast
                     #:unsupported-cps-ast-node
                     #:unsupported-cps-ast-node-type
                     #:cps-transform-ast*
                     #:cps-transform-sequence
                     #:cps-transform-eval
                     #:cps-simplify-form
                     #:cps-trampoline-run
                     #:*enable-trmc*))
