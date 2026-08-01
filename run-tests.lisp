;;;; run-tests.lisp — load "cl-cc-cps/test" and run the cl-weave suite.
;;;;
;;;; Bootstrap script: point ASDF's source registry at this checkout, then let
;;;; the inherited configuration resolve the dependencies. cl-cc-ast,
;;;; cl-cc-bootstrap and cl-weave must already be reachable through
;;;; CL_SOURCE_REGISTRY, which flake.nix exports for `nix flake check`,
;;;; `nix run .#test` and the devShell.
;;;;
;;;; Usage: sbcl --script run-tests.lisp

(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(asdf:initialize-source-registry
 `(:source-registry
   (:tree ,(script-directory))
   :inherit-configuration))

(handler-case
    (asdf:load-system "cl-cc-cps/test")
  (error (e)
    (format t "~&FAIL cl-cc-cps/test load: ~a~%" e)
    (finish-output)
    (uiop:quit 1)))

(if (uiop:symbol-call :cl-weave
                      :run-all
                      :reporter :spec
                      :pass-with-no-tests nil)
    (progn
      (format t "~&RESULT: ALL PASS~%")
      (finish-output)
      (uiop:quit 0))
    (progn
      (format t "~&RESULT: FAIL~%")
      (finish-output)
      (uiop:quit 1)))
