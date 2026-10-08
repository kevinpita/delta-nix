# delta-nix

Nix package, Home Manager module, and NixOS module for [Delta](https://delta.dev), the multiplayer environment for coding with AI agents from the Zed team.

The package repackages the official prebuilt release (Delta is closed source). Flake systems: `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

The attribute is `delta-dev`, not `delta`, because nixpkgs already uses `delta` for the git diff pager. Both install a `delta` binary, so do not install them in the same profile.

## Unfree license

Delta is unfree. This flake's own `packages` allow it. When you use the overlay or the modules, allow it in your nixpkgs configuration:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "delta-dev";
```

## Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    delta-nix = {
      url = "github:kevinpita/delta-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, delta-nix, ... }: {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "delta-dev";
      };
      modules = [
        delta-nix.homeModules.default
        {
          home = {
            username = "alice";
            homeDirectory = "/home/alice";
            stateVersion = "26.05";
          };
          programs.delta-dev.enable = true;
        }
      ];
    };
  };
}
```

No overlay is required. The module uses this repository's package unless you set `programs.delta-dev.package`.

## NixOS

Add `delta-nix.nixosModules.default` to the `modules` list of your `nixpkgs.lib.nixosSystem` call. Then configure:

```nix
programs.delta-dev.enable = true;
```

## Package only

```sh
nix run github:kevinpita/delta-nix
nix profile install github:kevinpita/delta-nix
```

Use `delta-nix.packages.${system}.default` in a shell or package list. Use `delta-nix.overlays.default` to add `pkgs.delta-dev`.

On Linux the package installs the `delta` CLI, the desktop entry, and icons. On macOS it installs `Delta.app` under `Applications` and links the CLI into `bin`.

Delta's built-in updater cannot replace files in the Nix store. Update through this flake instead.

## Development

Run these commands from the repository root:

```sh
nix develop
nix fmt
nix flake check --all-systems --no-build
nix build .#delta-dev
./result/bin/delta --help
```

For new, untracked files, use `nix flake check "path:$PWD" --all-systems --no-build` until the files are added to Git.

## Updates

`sources.json` holds the version, release URLs, and hashes. The update workflow checks the delta.dev release API hourly. It builds the package and evaluates the flake before it creates a pull request.

```sh
./scripts/update.sh --check
./scripts/update.sh --version 0.19.0
```
