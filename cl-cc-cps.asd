;;;; cl-cc-cps.asd — CPS transformation for the cl-cc compiler.
;;;;
;;;; Extracted from the cl-cc monorepo (docs/notes/repo-split-design.md
;;;; §10-7, 2026-08-01 audit): cl-cc-cps's only dependencies are
;;;; cl-cc-bootstrap and cl-cc-ast, both already externalized, and its only
;;;; in-tree reverse dependent is packages/compile, which keeps its own
;;;; integration tests against cl-cc/cps:: internals in the monorepo.
;;;;
;;;; NOTE on src/cps-simplify.lisp, src/cps-trampoline.lisp and
;;;; src/cps-trmc.lisp: these three files are carried over from the monorepo
;;;; unchanged, but — exactly as in the monorepo's cl-cc-cps.asd — they are
;;;; NOT listed in :components below. cps.lisp already defines every
;;;; function these three files define (trmc-transform-defun-form,
;;;; cps-trampoline-run, cps-simplify-form, ...), so the three files were
;;;; already dead/orphaned in the monorepo before this extraction; carrying
;;;; them here preserves that status quo rather than silently discarding or
;;;; silently reviving them. See the extraction report for details.
;;;;
;;;; Both systems live in this one file; there is no separate
;;;; cl-cc-cps-test.asd. System names are written as STRINGS rather than
;;;; #:symbols or :keywords, so that reading this file does not depend on the
;;;; reader's current package state.

(in-package #:asdf-user)

(defsystem "cl-cc-cps"
  :description "CPS transformation for the cl-cc Common Lisp compiler"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  ;; Single source of truth for the version: flake.nix reads this form, and
  ;; release.yml (if/when added) would refuse to publish a tag that
  ;; disagrees with it.
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-cps"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-cps/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-cps.git")
  :depends-on ("cl-cc-bootstrap" "cl-cc-ast")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "cps")
   (:file "cps-ast")
   (:file "cps-ast-control")
   (:file "cps-ast-extended")
   (:file "cps-ast-functional")))

(defsystem "cl-cc-cps/test"
  :description "Test system for cl-cc-cps, running under cl-weave."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-cps"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-cps/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-cps.git")
  :depends-on ("cl-cc-cps" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "cps-boundary-test")
   (:file "cps-transform-coverage-test")
   (:file "cps-trmc-test"))
  :perform (test-op (op system)
             (declare (ignore op system))
             (uiop:symbol-call :cl-weave :run-all
                               :reporter :spec
                               :pass-with-no-tests nil)))
