{
  description = "breakin-cremental - Godot game";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ]
        (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # xvfb-run: tests/shots.gd renders offscreen. nodejs: assets/audio/gen.mjs synthesises the sounds
          packages = [ pkgs.godot pkgs.xvfb-run pkgs.nodejs ];
        };
      });
    };
}
