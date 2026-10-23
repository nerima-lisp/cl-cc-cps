{
  description = "CPS transformation for the cl-cc Common Lisp compiler";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-cc-ast and cl-cc-bootstrap are consumed purely as raw ASDF source
    # trees (`cl.lispDerivation`'s `src`); this flake never touches their own
    # packages/checks outputs. `flake = false` fetches just the source, so
    # their dev-only inputs never enter this lock file. That is also why
    # neither carries `inputs.nixpkgs.follows`: the org standard mandates it
    # so an input cannot drag in a second nixpkgs, but a `flake = false`
    # input has no inputs of its own to redirect. cl-nix-forge and
    # treefmt-nix below are real flake inputs, and both carry it.
    #
    # Both cl-cc-cps library dependencies (see cl-cc-cps.asd's :depends-on),
    # pinned to their main SHAs in the W1 collection pinset.
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/a45c5acecfccb91a43f6a04251e8a5d6ec3d3213";
      flake = false;
    };
    cl-cc-bootstrap = {
      url = "github:nerima-lisp/cl-cc-bootstrap/027f6c9826010c15789454e69abd2930738b50af";
      flake = false;
    };

    # Test-only: cl-weave is the org's test framework, pinned to the release
    # tag in the W1 pinset.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      flake = false;
    };

    # The org flake preset. Everything this file would otherwise spell out
    # by hand — `.asd` version extraction, `forAllSystems`, the treefmt eval
    # wired to both `formatter` and `checks.formatting`, the run-tests.lisp
    # gate, the `apps.test`/`apps.default` pair, the devShell and the
    # overlay — is one `mkPackageFlake` call below. Pinned to a release TAG:
    # a bare `github:nerima-lisp/cl-nix-forge` follows that repository's
    # default branch and would change this build without warning.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Structure-editing lint gate for Lisp sources, wired the same way
    # cl-cc-type and cl-cc-bootstrap wire it: `paredit-cli.lib.${system}.
    # mkLintCheck` as a `checks.paredit-lint` entry, so a logic-bug lint
    # finding fails `nix flake check` instead of staying an ad hoc local
    # invocation. Pinned to its latest release tag.
    paredit-cli = {
      url = "github:takeokunn/paredit-cli/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-cc-ast,
      cl-cc-bootstrap,
      cl-weave,
      cl-nix-forge,
      paredit-cli,
      treefmt-nix,
    }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
      ];

      # cl-cc-cps has a small test suite; the
      # preset's default timeout is generous enough on its own, but this is
      # spelled out explicitly so the local `sbcl --script run-tests.lisp`
      # invocation and the `checks.default`/`apps.test` gate cannot drift.
      testTimeout = 120;
    in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        ;
      pname = "cl-cc-cps";

      # Single source of truth for the package version: the `:version` form
      # in cl-cc-cps.asd.
      asd = ./cl-cc-cps.asd;

      # Required, and it must be a path literal rather than `self`: a
      # flake's `self` is string-like and `lib.fileset` refuses it.
      root = ./.;

      meta = {
        description = "CPS transformation (continuation-passing style conversion) for cl-cc, extracted from the monorepo";
        homepage = "https://github.com/nerima-lisp/cl-cc-cps";
        license = lib.licenses.mit;
      };

      # `lispDependencies` is what `packages.cl-cc-cps` itself needs to load
      # (cl-cc-cps.asd's `:depends-on ("cl-cc-bootstrap" "cl-cc-ast")`);
      # `lispCheckDependencies` is what only the `/test` system needs
      # (cl-weave), so it stays off the library's own registry and reaches
      # the check derivation and the generated devShell only.
      lispDependencies = ctx: [
        (ctx.cl.lispDerivation {
          lispSystem = "cl-cc-bootstrap";
          version = ctx.cl.fromAsdSystem (cl-cc-bootstrap + "/cl-cc-bootstrap.asd");
          src = cl-cc-bootstrap;
        })
        (ctx.cl.lispDerivation {
          lispSystem = "cl-cc-ast";
          version = ctx.cl.fromAsdSystem (cl-cc-ast + "/cl-cc-ast.asd");
          src = cl-cc-ast;
        })
      ];
      lispCheckDependencies = ctx: [
        (ctx.cl.lispDerivation {
          lispSystem = "cl-weave";
          version = ctx.cl.fromAsdSystem (cl-weave + "/cl-weave.asd");
          src = cl-weave;
        })
      ];

      # `checks.default` and `apps.test` are both run-tests.lisp, driven
      # from this one number, so the command a contributor runs by hand
      # (`nix develop`, then `sbcl --script run-tests.lisp`) and the gate CI
      # runs cannot drift apart.
      timeoutSeconds = testTimeout;

      # No `docs` attribute: unlike cl-cc-ast/cl-cc-bootstrap/cl-cc-type,
      # this extraction did not stand up an MkDocs Material site (see the
      # extraction report). `docs = null` (the preset's default) omits the
      # docs package and its check entirely rather than failing on a missing
      # docs/mkdocs.yml.

      # ONE treefmt evaluation drives `nix fmt` and the `checks.formatting`
      # gate, so the formatter and the CI gate can never disagree about what
      # "formatted" means. Scope stays the preset's Nix-only default:
      # nixfmt is a low-diff, zero-footgun formatter, whereas a YAML
      # formatter mangles the GitHub Actions `on:` key.
      treefmt.evalModule = treefmt-nix.lib.evalModule;

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching.
      extraOutputs = ctx: {
        checks = {
          orphan-tests = ctx.pkgs.runCommand "cl-cc-cps-orphan-tests" {
            src = ctx.src;
            nativeBuildInputs = [ ctx.pkgs.sbcl ];
          } ''
            cat > orphan-tests.lisp <<'LISP'
            (require :asdf)

            (defun component-files (tree)
              (cond
                ((consp tree)
                 (if (and (eq (first tree) :file)
                          (stringp (second tree)))
                     (append (list (second tree))
                             (component-files (cddr tree)))
                     (append (component-files (first tree))
                             (component-files (rest tree)))))
                (t nil)))

            (let* ((forms
                     (with-open-file (stream (sb-ext:posix-getenv "ASD_FILE"))
                       (let ((*read-eval* nil))
                         (loop for form = (read stream nil :eof)
                               until (eq form :eof)
                               collect form))))
                   (test-system
                     (find-if
                       (lambda (form)
                         (and (consp form)
                              (symbolp (first form))
                              (string-equal (symbol-name (first form)) "DEFSYSTEM")
                              (equal (second form) "cl-cc-cps/test")))
                       forms))
                   (component-names (component-files (getf (cddr test-system) :components)))
                   (test-files
                     (directory
                       (merge-pathnames "*-test.lisp"
                                        (uiop:ensure-directory-pathname
                                          (sb-ext:posix-getenv "TEST_DIR")))))
                   (orphans
                     (remove-if
                       (lambda (file)
                         (member (pathname-name file) component-names :test #'string=))
                       test-files)))
              (when (null test-files)
                (error "No candidate test files found under t/"))
              (if orphans
                  (progn
                    (dolist (file orphans)
                      (format *error-output* "orphan test file: t/~a.lisp~%"
                              (pathname-name file)))
                    (error "Found ~d orphan test file(s)" (length orphans)))
                  (format t "Checked ~d test files; no orphans found.~%"
                          (length test-files))))
            LISP
            ASD_FILE="$src/cl-cc-cps.asd" TEST_DIR="$src/t" sbcl --script orphan-tests.lisp
            touch "$out"
          '';
          paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
            inherit (ctx) src;
            name = "cl-cc-cps-paredit-lint";
          };
        };
      };
    };
}
