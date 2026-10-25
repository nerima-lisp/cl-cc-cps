# Glossary

## transform

- Definition: Converts bootstrap S-expressions and AST nodes to continuation-passing style. `cps-transform` handles the bootstrap subset. `cps-transform-ast` transforms one AST node with a supplied continuation, while `cps-transform-ast*` wraps the result in a lambda with a fresh outer continuation. `cps-transform*` dispatches to the AST or bootstrap entry point based on the input type.
- Package: `cl-cc/cps/transform`
- Key types: `unsupported-cps-ast`
- Key functions: `cps-transform`, `cps-transform*`, `cps-transform-ast`, `cps-transform-ast*`, `cps-transform-sequence`, `cps-transform-eval`, `unsupported-cps-ast-node`, `unsupported-cps-ast-node-type`
- Other contexts: The transform system uses `simplify`, `trampoline`, and `trmc` through their feature packages.

## simplify

- Definition: Walks a CPS form bottom-up, substitutes arguments for parameters in calls to one-parameter lambdas (beta reduction), and removes one-parameter lambda wrappers around calls (eta reduction). It repeats until the next form is `equal` to the current form.
- Package: `cl-cc/cps/simplify`
- Key types: None.
- Key functions: `cps-simplify-form`
- Other contexts: The bootstrap `cps-transform` entry point simplifies its generated form.

## trampoline

- Definition: Rewrites a continuation lambda whose body is a direct tail call into a tagged thunk form. The runtime runner forces trampoline-thunk objects until a result is reached.
- Package: `cl-cc/cps/trampoline`
- Key types: None.
- Key functions: `cps-trampoline-form`, `cps-trampoline-run`
- Other contexts: The transform feature uses the form rewriter and its generated loop internally.

## trmc

- Definition: Rewrites a tail-position chain of `cons` calls ending in a direct self-call into a worker with an accumulator. The pass handles required-argument `defun` forms; setting `*enable-trmc*` to `nil` disables it.
- Package: `cl-cc/cps/trmc`
- Key types: None.
- Key functions: `trmc-transform-defun-form`
- Other contexts: The transform feature applies this pass while converting AST `defun` nodes.
