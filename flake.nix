{
  description = "hi-shell: a Material 3 Expressive desktop shell for Hyprland, built on Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # hi-shell needs Quickshell 0.3+ (Hyprland, Pipewire, Bluetooth and Networking modules).
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: pkgs: rec {
        hi-shell = pkgs.callPackage ./nix/package.nix { quickshell = quickshell.packages.${system}.default; };
        default = hi-shell;
      });

      overlays.default = final: _prev: {
        hi-shell = final.callPackage ./nix/package.nix { quickshell = quickshell.packages.${final.system}.default; };
      };

      homeManagerModules = rec {
        hi-shell = import ./nix/hm-module.nix self;
        default = hi-shell;
      };
    };
}
