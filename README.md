# cl-cc-cps

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

CPS (continuation-passing style) transformation for the
[cl-cc](https://github.com/nerima-lisp/cl-cc) Common Lisp compiler: converts
`cl-cc/ast` nodes (and a small bootstrap S-expression subset) into
continuation-passing form, with beta/eta simplification and Tail Recursion
Modulo Cons (TRMC) optimization for list-building self-recursion. Everything
is exported from the `cl-cc/cps` package.

## Why this one was safe to extract

A 2026-08-01 audit (`docs/notes/repo-split-design.md` §10-7 in the monorepo)
found that `cl-cc/cps`'s only dependencies are
[`cl-cc-ast`](https://github.com/nerima-lisp/cl-cc-ast) and
[`cl-cc-bootstrap`](https://github.com/nerima-lisp/cl-cc-bootstrap), both
already externalized, zero external `cl-cc/cps::` internals-reaching code
outside its own package other than `packages/compile/tests/` (compile's own
integration tests, which stay in the monorepo), and its only in-tree reverse
dependent is `packages/compile`.

## Usage

```lisp
(asdf:load-system "cl-cc-cps")

(cl-cc/cps:cps-transform-ast* some-ast-node)
```

## A note on three source files

`src/cps-simplify.lisp`, `src/cps-trampoline.lisp` and `src/cps-trmc.lisp`
ship in this repository but are deliberately **not** listed in
`cl-cc-cps.asd`'s `:components`. `src/cps.lisp` already defines every
function these three files define — they were dead, unloaded duplicates
already in the monorepo before this extraction (the same "double-definition
trap" class of bug documented for other packages in this org). This
extraction preserves that status quo rather than silently reviving or
silently deleting them; see `cl-cc-cps.asd`'s header comment for detail.

## Install

```nix
# flake.nix
inputs.cl-cc-cps = {
  url = "github:nerima-lisp/cl-cc-cps/v0.1.0";
  flake = false;
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch.

## Development

```sh
nix develop      # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test    # run the test suite
nix flake check   # tests + formatting + paredit lint, the same gate CI uses
nix fmt           # format Nix sources (treefmt)
```

Tests live in `t/` and run under
[cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test
framework.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
