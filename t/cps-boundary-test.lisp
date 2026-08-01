;;;; t/cps-boundary-test.lisp — module boundary tests for cl-cc-cps
;;;;
;;;; cl-cc's own suite covers CPS transformation through the full pipeline.
;;;; What is pinned here is the dependency closure, which is what this
;;;; extraction was for: cl-cc-cps's only dependencies are cl-cc-bootstrap
;;;; and cl-cc-ast (docs/notes/repo-split-design.md §10-7 in the monorepo),
;;;; and it must not gain a dependency on anything downstream of it.

(in-package :cl-cc-cps/test)

(describe-sequential "cl-cc-cps dependency closure"
  (it "has its two declared dependencies present"
    (dolist (name '("CL-CC/AST" "CL-CC/BOOTSTRAP"))
      (expect (find-package name) :to-be-truthy)))

  (it "loads without the VM, optimizer, codegen, compile, expand, type or parse stages"
    ;; CPS conversion sits between the AST and the optimizer/VM stages.
    ;; Nothing here should need any of them, and if that changed it would
    ;; put cl-cc-cps back inside a cycle this extraction removed.
    (dolist (name '("CL-CC/VM" "CL-CC/OPTIMIZE" "CL-CC/CODEGEN" "CL-CC/COMPILE"
                    "CL-CC/EXPAND" "CL-CC/TYPE" "CL-CC/PARSE"))
      (expect (find-package name) :to-be nil))))

(describe-sequential "cl-cc-cps public surface"
  (it "exports the entry points a consumer transforms AST/sexp forms through"
    (dolist (name '("CPS-TRANSFORM" "CPS-TRANSFORM*" "CPS-TRANSFORM-AST"
                    "CPS-TRANSFORM-AST*" "CPS-TRANSFORM-SEQUENCE"
                    "CPS-TRANSFORM-EVAL" "CPS-SIMPLIFY-FORM"
                    "CPS-TRAMPOLINE-RUN" "*ENABLE-TRMC*"))
      (expect (nth-value 1 (find-symbol name :cl-cc/cps)) :to-be :external))))

(describe-sequential "bootstrap S-expression CPS transform"
  (it "transforms a literal integer into a continuation-passing lambda"
    (let ((form (cl-cc/cps:cps-transform 42)))
      (expect (and (consp form) (eq (first form) 'lambda)) :to-be-truthy))))
