# TEMPLATE. Replace <repo> below with this repository's name, and the
# description string with this repository's package.json "description", then
# delete this header.
#
# Wave 0 (2026-08-30): this is the target shape for every repository,
# including mc-kernel -- it is NOT a byte-for-byte copy of mc-kernel's
# current origin/main flake.nix. Two differences from kernel's current file,
# both intentional: oxlint and ast-grep are provided by Nix rather than npm
# (2026-08-01 decision, PACKAGE_STANDARD.md "oxlint は package.json の
# devDependency ではなく Nix 提供" -- kernel already has this part), and the
# mktemp-based corepack shellHook below replaces kernel's current
# `mkdir -p "$PWD/.corepack"` form (a `.corepack/` directory some repos were
# committing by mistake; delete it and add it to .gitignore instead). Kernel
# itself has not adopted the mktemp form yet -- when it does, this template
# and kernel's flake.nix converge. This template also omits kernel's
# `formatter = forAllSystems (... nixfmt)` output; add it back if you want
# `nix fmt` in your repo, it is not an org-wide requirement.
#
# mx-ui and mc-compose additionally add `pkgs.playwright-driver.browsers` and
# export `PLAYWRIGHT_BROWSERS_PATH` in shellHook (keep any existing browser
# path handling already in your flake).
#
# Unlike a package-manager-level flake, this one does not declare any
# `packages.*` output: this org's CI (workflow-templates/ci.yml) runs
# pnpm/vitest directly on ubuntu-latest inside `nix develop`, and never builds
# a Nix derivation of the package itself. This flake exists only to give
# `nix develop` (via direnv/.envrc `use flake`) a devShell with the right
# Node.js/oxlint/ast-grep versions, so every contributor's toolchain resolves
# to the same nixpkgs regardless of what is installed on their machine.
#
# Sibling @nerima-games/* packages are NOT referenced as flake inputs here.
# Cross-repo dependencies in this org flow through package.json + GitHub
# Packages (see RELEASE_STANDARD.md), not through Nix flake inputs -- that is
# a difference from orgs (e.g. nerima-lisp) where the language's own package
# manager is Nix-shaped.
{
  description = "<package.json の description をそのまま>";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_24
              pkgs.corepack_24
              pkgs.typescript-language-server
              pkgs.oxlint
              pkgs.ast-grep
            ];

            shellHook = ''
              corepackDir="$(mktemp -d "''${TMPDIR:-/tmp}/<repo>-corepack.XXXXXX")"
              corepack enable --install-directory "$corepackDir"
              export PATH="$corepackDir:$PATH"
            '';
          };
        }
      );
    };
}
