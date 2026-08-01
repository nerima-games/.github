# TEMPLATE. Replace the description string below (and PACKAGE if you copy the
# name into the description text) with this repository's package.json
# "description", then delete this header.
#
# Unlike a package-manager-level flake, this one does not declare any
# `packages.*` or `checks.*` output and does not do a `nix flake check` gate:
# this org's CI (workflow-templates/ci.yml) runs pnpm/vitest directly on
# ubuntu-latest and never invokes Nix. This flake exists only to give
# `nix develop` (via direnv/.envrc `use flake`) a devShell with the right
# Node.js version, so every contributor's toolchain resolves to the same
# nixpkgs regardless of what is installed on their machine.
#
# Sibling @nerima-games/* packages are NOT referenced as flake inputs here.
# Cross-repo dependencies in this org flow through package.json + GitHub
# Packages (see RELEASE_STANDARD.md), not through Nix flake inputs -- that is
# a difference from orgs (e.g. nerima-lisp) where the language's own package
# manager is Nix-shaped.
{
  description = "PACKAGE: ONE-LINE DESCRIPTION, matching package.json's \"description\" field.";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      # Only what is actually exercised: x86_64-linux by CI, aarch64-darwin by
      # the maintainer. Declaring a platform nothing builds makes
      # `nix flake check --all-systems` fail rather than skip it.
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
          # Node 24 matches the `engines` field in package.json and the CI
          # runner (workflow-templates/ci.yml). pnpm comes from corepack
          # rather than nixpkgs so that the version is decided by the
          # `packageManager` field in package.json -- one source of truth
          # instead of two that can drift.
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs_24
              pkgs.corepack_24
              pkgs.typescript-language-server
            ];

            shellHook = ''
              mkdir -p "$PWD/.corepack"
              corepack enable --install-directory "$PWD/.corepack"
              export PATH="$PWD/.corepack:$PATH"
            '';
          };
        }
      );
    };
}
