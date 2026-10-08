{ config, lib, ... }:
let
  cfg = config.programs.delta-dev;
in
{
  imports = [ ./common.nix ];
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
