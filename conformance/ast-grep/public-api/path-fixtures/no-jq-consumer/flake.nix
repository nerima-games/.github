{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
      devShells = nixpkgs.lib.genAttrs systems (system: {
        default =
          let pkgs = import nixpkgs { inherit system; };
          in pkgs.mkShell {
            packages = [ pkgs.ast-grep ];
          };
      });
    };
}
