{
  description = "Nix flake for Delta, a multiplayer environment for coding with AI agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      overlay = final: prev: {
        delta-dev = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "delta-dev";
        };
      in
      {
        packages = {
          default = pkgs.delta-dev;
          delta-dev = pkgs.delta-dev;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.delta-dev}/bin/delta";
          };
          delta-dev = {
            type = "app";
            program = "${pkgs.delta-dev}/bin/delta";
          };
        };

        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            curl
            jq
            nixfmt
          ];
        };
      }
    )
    // {
      overlays.default = overlay;
      homeManagerModules.default = import ./modules/home-manager.nix;
      homeModules.default = import ./modules/home-manager.nix;
      nixosModules.default = import ./modules/nixos.nix;
    };
}
