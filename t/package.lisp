;;;; t/package.lisp — test package for cl-cc-cps

(defpackage :cl-cc-cps/test
  (:use :cl :cl-weave)
  (:shadowing-import-from :cl-weave :describe))
