{
  description = "A nix flake for rustowl";

  nixConfig = {
    extra-substituters = [
      "https://mrcjkb.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "mrcjkb.cachix.org-1:KhpstvH5GfsuEFOSyGjSTjng8oDecEds7rbrI96tjA4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-manifest = {
      url = "https://static.rust-lang.org/dist/2025-02-22/channel-rust-nightly.toml";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = builtins.attrNames nixpkgs.legacyPackages;
      perSystem = attrs @ {
        system,
        pkgs,
        ...
      }: let
        pkgs = attrs.pkgs.extend self.overlays.default;
        git-hooks-check = inputs.git-hooks.lib.${system}.run {
          src = self;
          hooks = {
            alejandra.enable = true;
            editorconfig-checker.enable = true;
          };
        };
      in {
        # use fenix overlay
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [inputs.fenix.overlays.default];
        };

        packages = with pkgs; {
          default = rustowl;
          inherit
            rustowl
            rustowl-nvim
            ;
        };

        devShells.default = pkgs.mkShell {
          name = "rustowl-flake devShell";
          inherit (git-hooks-check) shellHook;
          buildInputs =
            self.checks.${system}.git-hooks-check.enabledPackages;
        };

        checks = rec {
          default = git-hooks-check;
          inherit
            git-hooks-check
            ;
        };
      };
      flake = {
        overlays.default = import ./nix/overlay.nix {inherit self inputs;};
      };
    };
}
