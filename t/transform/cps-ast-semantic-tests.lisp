;;;; tests/unit/compile/cps-ast-semantic-tests.lisp — CPS AST semantic evaluation tests

(in-package :cl-cc/cps/transform/test)


;;; ─────────────────────────────────────────────────────────────────────────
;;; AST CPS — semantic (evaluable forms)
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "cps-ast-binop add"
  (destructuring-bind (op lhs rhs expected) (list '+ 3 4 7)
    (let ((ast (cl-cc/ast:make-ast-binop :op op
                                   :lhs (cl-cc/ast:make-ast-int :value lhs)
                                   :rhs (cl-cc/ast:make-ast-int :value rhs))))
    (expect (= expected (run-cps-ast ast)) :to-be-truthy))))

(it-sequential "cps-ast-binop sub"
  (destructuring-bind (op lhs rhs expected) (list '- 9 4 5)
    (let ((ast (cl-cc/ast:make-ast-binop :op op
                                   :lhs (cl-cc/ast:make-ast-int :value lhs)
                                   :rhs (cl-cc/ast:make-ast-int :value rhs))))
    (expect (= expected (run-cps-ast ast)) :to-be-truthy))))

(it-sequential "cps-ast-binop mul"
  (destructuring-bind (op lhs rhs expected) (list '* 3 4 12)
    (let ((ast (cl-cc/ast:make-ast-binop :op op
                                   :lhs (cl-cc/ast:make-ast-int :value lhs)
                                   :rhs (cl-cc/ast:make-ast-int :value rhs))))
    (expect (= expected (run-cps-ast ast)) :to-be-truthy))))

(it-sequential "cps-ast-if-branch truthy-takes-then"
  (destructuring-bind (cond-val then-val else-val expected) (list 1 10 20 10)
    (let ((ast (cl-cc/ast:make-ast-if :cond (cl-cc/ast:make-ast-int :value cond-val)
                                :then (cl-cc/ast:make-ast-int :value then-val)
                                :else (cl-cc/ast:make-ast-int :value else-val))))
    (expect (= expected (run-cps-ast ast)) :to-be-truthy))))

(it-sequential "cps-ast-if-branch nil-takes-else"
  (destructuring-bind (cond-val then-val else-val expected) (list nil 10 20 20)
    (let ((ast (cl-cc/ast:make-ast-if :cond (cl-cc/ast:make-ast-int :value cond-val)
                                :then (cl-cc/ast:make-ast-int :value then-val)
                                :else (cl-cc/ast:make-ast-int :value else-val))))
    (expect (= expected (run-cps-ast ast)) :to-be-truthy))))

(it-sequential "cps-evaluable-forms integer"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-int :value 42) 42)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms progn"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-progn
                           :forms (list (cl-cc/ast:make-ast-int :value 1)
                                        (cl-cc/ast:make-ast-int :value 2)
                                        (cl-cc/ast:make-ast-int :value 99))) 99)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms let"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-let
                           :bindings (list (cons 'x (cl-cc/ast:make-ast-int :value 3))
                                           (cons 'y (cl-cc/ast:make-ast-int :value 4)))
                           :body (list (cl-cc/ast:make-ast-binop
                                        :op '+
                                        :lhs (cl-cc/ast:make-ast-var :name 'x)
                                        :rhs (cl-cc/ast:make-ast-var :name 'y)))) 7)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms print"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 42)) 42)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms quote-symbol"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-quote :value 'hello) 'hello)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms quote-list"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-quote :value '(1 2 3)) '(1 2 3))
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-evaluable-forms the"
  (destructuring-bind (ast expected) (list (cl-cc/ast:make-ast-the :type 'integer
                                              :value (cl-cc/ast:make-ast-int :value 7)) 7)
    (expect (run-cps-ast ast) :to-equal expected)))

(it-sequential "cps-ast-setq-returns-value"
  (let ((setq-ast (cl-cc/ast:make-ast-setq
                   :var 'cl-cc-test-setq-var
                   :value (cl-cc/ast:make-ast-int :value 55))))
    ;; Bind the target var so SBCL doesn't complain about an unbound special
    (let ((cl-cc-test-setq-var nil))
      (declare (special cl-cc-test-setq-var))
      (handler-bind ((warning #'muffle-warning))
        (let ((result (run-cps-ast setq-ast)))
          (expect (= 55 result) :to-be-truthy)
          (expect (= 55 cl-cc-test-setq-var) :to-be-truthy))))))

(it-sequential "cps-ast-block lexical exit semantics"
  (let* ((early
           (cl-cc/ast:make-ast-block
            :name 'b
            :body (list
                   (cl-cc/ast:make-ast-return-from
                    :name 'b
                    :value (cl-cc/ast:make-ast-int :value 3))
                   (cl-cc/ast:make-ast-int :value 99))))
         (continued
           (cl-cc/ast:make-ast-binop
            :op '+
            :lhs early
            :rhs (cl-cc/ast:make-ast-int :value 4)))
         (nested
           (cl-cc/ast:make-ast-block
            :name 'outer
            :body (list
                   (cl-cc/ast:make-ast-block
                    :name 'inner
                    :body (list
                           (cl-cc/ast:make-ast-return-from
                            :name 'inner
                            :value (cl-cc/ast:make-ast-int :value 5))))
                   (cl-cc/ast:make-ast-int :value 20))))
         (shadowed
           (cl-cc/ast:make-ast-block
            :name 'same
            :body (list
                   (cl-cc/ast:make-ast-block
                    :name 'same
                    :body (list
                           (cl-cc/ast:make-ast-return-from
                            :name 'same
                            :value (cl-cc/ast:make-ast-int :value 6))))
                   (cl-cc/ast:make-ast-int :value 21))))
         (nil-block
           (cl-cc/ast:make-ast-block
            :name nil
            :body (list
                   (cl-cc/ast:make-ast-return-from
                    :name nil
                    :value (cl-cc/ast:make-ast-int :value 8)))))
         (empty
           (cl-cc/ast:make-ast-block :name 'empty :body nil)))
    (expect (run-cps-ast
             (cl-cc/ast:make-ast-block
              :name 'normal
              :body (list (cl-cc/ast:make-ast-int :value 2))))
            :to-equal 2)
    (expect (run-cps-ast continued) :to-equal 7)
    (expect (run-cps-ast nested) :to-equal 20)
    (expect (run-cps-ast shadowed) :to-equal 21)
    (expect (run-cps-ast nil-block) :to-equal 8)
    (expect (run-cps-ast empty) :to-be nil)
    (let* ((cl-cc-test-block-counter 0)
           (increment
             (cl-cc/ast:make-ast-setq
              :var 'cl-cc-test-block-counter
              :value
              (cl-cc/ast:make-ast-binop
               :op '+
               :lhs (cl-cc/ast:make-ast-var :name 'cl-cc-test-block-counter)
               :rhs (cl-cc/ast:make-ast-int :value 1))))
           (node
             (cl-cc/ast:make-ast-block
              :name 'effects
              :body
              (list
               (cl-cc/ast:make-ast-return-from :name 'effects :value increment)
               (cl-cc/ast:make-ast-setq
                :var 'cl-cc-test-block-counter
                :value (cl-cc/ast:make-ast-int :value 99))))))
      (declare (special cl-cc-test-block-counter))
      (handler-bind ((warning (lambda (condition)
                                (declare (ignore condition))
                                (muffle-warning))))
        (expect (run-cps-ast node) :to-equal 1))
      (expect cl-cc-test-block-counter :to-equal 1))
    (let* ((cl-cc-test-block-counter 0)
           (skipped-inner
             (cl-cc/ast:make-ast-setq
              :var 'cl-cc-test-block-counter
              :value (cl-cc/ast:make-ast-int :value 10)))
           (skipped-outer
             (cl-cc/ast:make-ast-setq
              :var 'cl-cc-test-block-counter
              :value (cl-cc/ast:make-ast-int :value 20)))
           (outer
             (cl-cc/ast:make-ast-block
              :name 'outer
              :body
              (list
               (cl-cc/ast:make-ast-block
                :name 'inner
                :body
                (list
                 (cl-cc/ast:make-ast-return-from
                  :name 'outer
                  :value (cl-cc/ast:make-ast-int :value 3))
                 skipped-inner))
               skipped-outer)))
           (continued-after-outer
             (cl-cc/ast:make-ast-binop
              :op '+
              :lhs outer
              :rhs (cl-cc/ast:make-ast-int :value 4))))
      (declare (special cl-cc-test-block-counter))
      (handler-bind ((warning (lambda (condition)
                          (declare (ignore condition))
                          (muffle-warning))))
  (expect (run-cps-ast continued-after-outer) :to-equal 7))
      (expect cl-cc-test-block-counter :to-equal 0))))

;;; ─────────────────────────────────────────────────────────────────────────
;;; AST CPS — structural ("is it a CPS lambda?")
;;; These forms are transformed correctly but cannot be trivially evaluated
;;; because they involve non-local control (block, go, throw) or closures.
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "cps-ast-structural-shape lambda"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-lambda
     :params '(x)
     :body (list (cl-cc/ast:make-ast-int :value 1))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape block"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-block
     :name 'b
     :body (list (cl-cc/ast:make-ast-int :value 1))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape return-from"
  (destructuring-bind (ast)
      (list
       (cl-cc/ast:make-ast-block
        :name (quote b)
        :body
        (list
         (cl-cc/ast:make-ast-return-from
          :name (quote b)
          :value (cl-cc/ast:make-ast-int :value 1)))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape tagbody"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-tagbody
     :tags (list (cons 'tag1 (list (cl-cc/ast:make-ast-int :value 1))))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape go"
  (let ((ast (cl-cc/ast:make-ast-tagbody
              :tags (list (cons (quote tag1)
                                (list (cl-cc/ast:make-ast-go :tag (quote tag1))))))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape catch"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-catch
     :tag  (cl-cc/ast:make-ast-var :name 'my-tag)
     :body (list (cl-cc/ast:make-ast-int :value 42))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape throw"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-throw
     :tag   (cl-cc/ast:make-ast-var :name 'my-tag)
     :value (cl-cc/ast:make-ast-int :value 42)))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape unwind-protect"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-unwind-protect
     :protected (cl-cc/ast:make-ast-int :value 42)
     :cleanup   (list (cl-cc/ast:make-ast-int :value 0))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape flet"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-flet
     :bindings (list (list 'double '(x)
                           (cl-cc/ast:make-ast-binop
                            :op '*
                            :lhs (cl-cc/ast:make-ast-int :value 2)
                            :rhs (cl-cc/ast:make-ast-var :name 'x))))
     :body (list (cl-cc/ast:make-ast-int :value 1))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "cps-ast-structural-shape labels"
  (destructuring-bind (ast) (list (cl-cc/ast:make-ast-labels
     :bindings (list (list 'id '(x) (cl-cc/ast:make-ast-var :name 'x)))
     :body (list (cl-cc/ast:make-ast-int :value 1))))
    (expect (is-cps-lambda (cl-cc/cps/transform:cps-transform-ast* ast)) :to-be-truthy)))

(it-sequential "fr-371-cps-tagbody-local-jump-semantics"
  (labels ((int (value) (cl-cc/ast:make-ast-int :value value))
           (var () (cl-cc/ast:make-ast-var :name (quote cl-cc-test-tag-counter)))
           (set-counter (value)
             (cl-cc/ast:make-ast-setq :var (quote cl-cc-test-tag-counter) :value value))
           (add (value)
             (cl-cc/ast:make-ast-binop :op (quote +) :lhs (var) :rhs (int value)))
           (run-with-counter (node expected)
             (let ((cl-cc-test-tag-counter 0))
               (declare (special cl-cc-test-tag-counter))
               (handler-bind ((warning (lambda (condition)
                                         (declare (ignore condition))
                                         (muffle-warning))))
                 (expect (run-cps-ast node) :to-be nil))
               (expect cl-cc-test-tag-counter :to-equal expected))))
    (expect (run-cps-ast (cl-cc/ast:make-ast-tagbody :tags nil)) :to-be nil)
    (expect (run-cps-ast
             (cl-cc/ast:make-ast-tagbody
              :tags (list (cons (quote final)
                                (list (int 42))))))
            :to-be nil)
    (run-with-counter
     (cl-cc/ast:make-ast-tagbody
      :tags (list
             (cons (quote start)
                   (list (set-counter (int 1))
                         (cl-cc/ast:make-ast-go :tag (quote done))
                         (set-counter (int 99))))
             (cons (quote done)
                   (list (set-counter (add 2))))))
     3)
    (run-with-counter
     (cl-cc/ast:make-ast-tagbody
      :tags (list
             (cons (quote first) (list (set-counter (int 1))))
             (cons (quote second) (list (set-counter (add 2))))))
     3)
    (run-with-counter
     (cl-cc/ast:make-ast-tagbody
      :tags (list
             (cons (quote loop)
                   (list (set-counter (add 1))
                         (cl-cc/ast:make-ast-if
                          :cond (cl-cc/ast:make-ast-binop
                                 :op (quote <) :lhs (var) :rhs (int 2))
                          :then (cl-cc/ast:make-ast-go :tag (quote loop))
                          :else (int 0))))))
     2)
    (run-with-counter
     (cl-cc/ast:make-ast-tagbody
      :tags (list
             (cons (quote outer-start)
                   (list
                    (cl-cc/ast:make-ast-tagbody
                     :tags (list
                            (cons (quote inner-start)
                                  (list (cl-cc/ast:make-ast-go :tag (quote same))))
                            (cons (quote same)
                                  (list (set-counter (int 10))))))))
             (cons (quote same) (list (set-counter (add 1))))))
     11)
    (run-with-counter
     (cl-cc/ast:make-ast-tagbody
      :tags (list
             (cons (quote outer-start)
                   (list
                    (cl-cc/ast:make-ast-tagbody
                     :tags (list
                            (cons (quote inner-start)
                                  (list (cl-cc/ast:make-ast-go
                                         :tag (quote outer-end))))))))
             (cons (quote skipped) (list (set-counter (int 99))))
             (cons (quote outer-end) (list (set-counter (int 7))))))
     7)))
