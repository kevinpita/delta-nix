{ lib, pkgs, ... }:
{
  options.programs.delta-dev = {
    enable = lib.mkEnableOption "Delta, a multiplayer environment for coding with AI agents";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../package.nix { };
      defaultText = lib.literalExpression "delta-nix.packages.\${system}.default";
      description = "Delta package to install. Delta is unfree, so allow the delta-dev package in nixpkgs.config.";
    };
  };
}
