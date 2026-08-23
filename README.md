# Nix configuration

The public half of my Nix flake configuration. It contains reusable Home Manager modules, NixOS modules, overlays, and development tooling.

My machine-specific hosts, infrastructure, secrets, and personal composition live in a separate private Git repository. This repository is intended to stay safe to publish and useful as a flake input; it is not a complete, drop-in operating-system configuration.

> Notice: This repository is a mirror of a Forgejo-hosted repository.

## What is here

- Home Manager modules for shell tools, development environments, Git, GPG, SSH, Hyprland, and desktop services.
- NixOS modules for common host concerns such as Docker, FIDO2, garbage collection, Hyprland with NVIDIA, OpenXLR, YubiKey, and ZFS.
- A combined overlay with custom fonts and `yubikey-touch-detector` fixes.
- Checks for the exported modules and desktop configuration.

Exported flake outputs:

- `homeModules`
- `nixosModules`
- `overlays.default`
- `packages.x86_64-linux`
- `checks.x86_64-linux`
- `devShells.x86_64-linux.default`

## Getting started

### Prerequisites

- Nix with flakes enabled. NixOS enables this through the `base` module; other systems need `nix-command` and `flakes` in their Nix configuration.
- Git.
- [Home Manager](https://github.com/nix-community/home-manager) when using the Home Manager modules or reference profiles.
- Linux on `x86_64` for the currently exported packages, checks, and profiles.

### Installation

Add this repository as an input to your own flake:

```nix
{
    inputs.nix-config.url = "github:mineugene/nix-config";

    outputs = { nixpkgs, home-manager, nix-config, ... }: {
        # Your outputs go here.
    };
}
```

Import the modules you want into a Home Manager configuration:

```nix
home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [
        nix-config.homeModules.git
        nix-config.homeModules.neovim
        nix-config.homeModules.zsh
        {
            home.username = "you";
            home.homeDirectory = "/home/you";
            home.stateVersion = "25.11";
        }
    ];
}
```

Or add a NixOS module to `nixosSystem`:

```nix
nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
        nix-config.nixosModules.base
        nix-config.nixosModules.nix-gc
    ];
}
```

Use the overlay when you need this repository's custom packages:

```nix
nixpkgs.overlays = [ nix-config.overlays.default ];
```

## OpenXLR module

`nixosModules.openxlr` integrates OpenXLR with PipeWire on Linux for the original Wave XLR (`0fd9:007d`). Import it from the downstream NixOS configuration:

```nix
modules = [
    nix-config.nixosModules.openxlr
];
```

The module enables PipeWire, WirePlumber, 32-bit ALSA support, PulseAudio compatibility, RTKit, and the upstream OpenXLR service. The OpenXLR daemon starts in the user's systemd session. After the first deployment, unplug and reconnect the interface once so its new udev permissions apply.

OpenXLR manages application channel assignments and Monitor output selection as writable user state; this public module does not hard-code either. Gain, mute, headphone volume, and low-impedance mode have been verified upstream on original Wave XLR hardware. OpenXLR exposes 48 V phantom power for this model, but upstream still marks that control as coded rather than separately verified on MK.1 hardware after its implementation.

## Local development

Clone the repository and enter its development shell:

```sh
git clone git@github.com:mineugene/nix-config.git
cd nix-config
nix develop
```

[`just`](https://github.com/casey/just) provides common commands:

```sh
just check                    # Run all flake checks
just lint                     # Run pre-commit checks
just fmt                      # Format tracked files
just update nixpkgs           # Update one flake input
```

Run `just` to list every command. `just boundary` verifies that public-repository boundaries are preserved and scans for leaked secrets.

## Desktop module

`homeModules.hyprland` configures the user-side Hyprland session, theme, remembered monitor topologies, Eww bar, Rofi, SwayNotificationCenter, Hyprlock, and Hypridle. NixOS owns installation and startup through UWSM. See [the Hyprland module README](home/modules/hyprland/README.md) for options, commands, service ownership, HDR setup, and validation.

## Private configuration

The private flake imports this repository and adds host definitions, infrastructure, secrets, and machine-specific settings. Keep those concerns outside this repository. The `boundary` check enforces that separation.
