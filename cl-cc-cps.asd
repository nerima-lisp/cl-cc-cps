;;;; cl-cc-cps.asd — CPS transformation for the cl-cc Common Lisp compiler.

(in-package #:asdf-user)

(defsystem "cl-cc-cps/simplify"
  :description "CPS form simplification"
  :pathname "src/simplify"
  :serial t
  :components ((:file "package")
               (:file "simplify")))

(defsystem "cl-cc-cps/trampoline"
  :description "CPS trampoline helpers"
  :pathname "src/trampoline"
  :serial t
  :components ((:file "package")
               (:file "trampoline")))

(defsystem "cl-cc-cps/trmc"
  :description "Tail recursion modulo cons transformation"
  :pathname "src/trmc"
  :serial t
  :components ((:file "package")
               (:file "trmc")))

(defsystem "cl-cc-cps/transform"
  :description "CPS transformation for AST and bootstrap forms"
  :depends-on ("cl-cc-bootstrap"
               "cl-cc-ast"
               "cl-cc-cps/simplify"
               "cl-cc-cps/trampoline"
               "cl-cc-cps/trmc")
  :pathname "src/transform"
  :serial t
  :components ((:file "package")
               (:file "cps")
               (:file "cps-ast")
               (:file "cps-ast-control")
               (:file "cps-ast-extended")
               (:file "cps-ast-functional")))

(defsystem "cl-cc-cps"
  :description "CPS transformation for the cl-cc Common Lisp compiler"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-cps"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-cps/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-cps.git")
  :depends-on ("cl-cc-cps/transform")
  :pathname "src"
  :components ((:file "package")))

(defsystem "cl-cc-cps/simplify/test"
  :description "Tests for CPS simplification"
  :depends-on ("cl-cc-cps/simplify" "cl-weave")
  :pathname "t/simplify"
  :serial t
  :components ((:file "package")
               (:file "cps-simplify-tests")))

(defsystem "cl-cc-cps/trampoline/test"
  :description "Tests for CPS trampoline helpers"
  :depends-on ("cl-cc-cps/trampoline" "cl-weave")
  :pathname "t/trampoline"
  :serial t
  :components ((:file "package")
               (:file "cps-trampoline-tests")))

(defsystem "cl-cc-cps/trmc/test"
  :description "Tests for tail recursion modulo cons"
  :depends-on ("cl-cc-cps/trmc" "cl-weave")
  :pathname "t/trmc"
  :serial t
  :components ((:file "package")
               (:file "cps-trmc-test")
               (:file "cps-migrated-tests")))

(defsystem "cl-cc-cps/transform/test"
  :description "Tests for CPS transformation"
  :depends-on ("cl-cc-cps" "cl-weave")
  :pathname "t/transform"
  :serial t
  :components ((:file "package")
               (:file "cps-tests")
               (:file "cps-ast-tests")
               (:file "cps-ast-extended-tests")
               (:file "cps-ast-semantic-tests")
               (:file "cps-ast-functional-tests")
               (:file "cps-ast-transform-tests")
               (:file "cps-boundary-test")
               (:file "cps-transform-coverage-test")))

(defsystem "cl-cc-cps/test"
  :description "Test system for cl-cc-cps, running under cl-weave."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-cps"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-cps/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-cps.git")
  :depends-on ("cl-cc-cps"
               "cl-cc-cps/simplify/test"
               "cl-cc-cps/trampoline/test"
               "cl-cc-cps/trmc/test"
               "cl-cc-cps/transform/test")
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-cps tests failed."))))
