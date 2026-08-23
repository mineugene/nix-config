{ pkgs, nixosSystem }:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            ../nixos/modules/hyprland-nvidia
            {
                nixpkgs.config.allowUnfree = true;
                system.stateVersion = "25.11";
            }
        ];
    };
    cfg = system.config;
in
assert cfg.security.pam.services ? hyprlock;
assert cfg.programs.hyprland.withUWSM;
assert !cfg.programs.hyprland.xwayland.enable;
pkgs.runCommandLocal "hyprlock-pam-check" { } ''
    touch "$out"
''
