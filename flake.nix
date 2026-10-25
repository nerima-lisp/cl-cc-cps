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

    # The org flake preset and shared feature/test check builders.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.7.4";
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
      sourceInclude = [ ./t/export-surface.txt ];

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
      extraOutputs =
        ctx:
        let
          cl = ctx.cl;
        in
        {
          checks = {
            feature-lint = cl.mkFeatureLintCheck {
              src = ./.;
              featureDefinitions = "nix/feature-dependencies.sexp";
              glossary = "docs/src/reference/glossary.md";
              glossaryHeadingPrefix = "## ";
              exportSurface = "t/export-surface.txt";
              mode = "transition";
              legacyInternalRefs = "t/legacy-internal-refs.sexp";
              forbiddenNames = [
                "phases"
                "misc"
                "utils"
                "helpers"
              ];
              numberedPrefixes = [
                "FR-"
                "W"
              ];
              packagePrefix = "cl-cc/cps/";
              infraSuffix = "/infra";
            };
            paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
              inherit (ctx) src;
              name = "cl-cc-cps-paredit-lint";
            };
            orphan-tests = cl.mkOrphanTestCheck {
              src = ./.;
              testRoots = [
                "t/simplify"
                "t/trampoline"
                "t/trmc"
                "t/transform"
              ];
              testSystems = [
                "cl-cc-cps/simplify/test"
                "cl-cc-cps/trampoline/test"
                "cl-cc-cps/trmc/test"
                "cl-cc-cps/transform/test"
              ];
            };
          };
        };
    };
}
