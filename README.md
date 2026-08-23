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
        nix-config.homeModules.fd
        nix-config.homeModules.fzf
        nix-config.homeModules.tmux
        nix-config.homeModules.zsh
        {
            home.username = "you";
            home.homeDirectory = "/home/you";
            home.stateVersion = "25.11";
        }
    ];
}
```

The Zsh widget bundle requires Git, FZF, and tmux. `homeModules.shared` (also
exported as `homeModules.default`) is an opinionated tool profile, not a host or
user definition. It defaults `home.stateVersion` to `25.11` for compatibility;
consumers should set their own Home Manager state version explicitly.

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

## .NET tools

`homeModules.dotnet` installs the combined .NET SDKs, netcoredbg, and these tools
throughout the user's profile; no `dotnet tool install -g` activation step is needed.

| NuGet tool           | Nix package       | Command             | Version  |
| -------------------- | ----------------- | ------------------- | -------- |
| EasyDotnet           | `easydotnet`      | `dotnet easydotnet` | 3.4.26   |
| dotnet-outdated-tool | `dotnet-outdated` | `dotnet outdated`   | 4.8.1    |
| dotnet-serve         | `dotnet-serve`    | `dotnet serve`      | 1.10.194 |
| ilspycmd             | `ilspycmd`        | `ilspycmd`          | 9.1      |

Outdated and ILSpy reuse packages from the locked nixpkgs. EasyDotnet and Serve
use `buildDotnetGlobalTool` with pinned NuGet versions
and hashes in `overlays/dotnet-tools/`. The default overlay exports those packages;
the Home Manager module also works without requiring consumers to apply the overlay.
The custom packages check their CLI versions during builds.

After applying Home Manager, verify the commands with `dotnet easydotnet -v`,
`dotnet outdated --version`, `dotnet serve --version`, and `ilspycmd --version`.

EF and ReportGenerator are project tools, not installed globally by this module.
Pin them in each .NET repository's `.config/dotnet-tools.json` and run
`dotnet tool restore` in development and CI. Match the EF tools' major version
to the project's EF Core version.

Update custom tools' versions and hashes through Nix, not `:Dotnet _server update`
or `dotnet tool update -g`, which can create competing mutable installs. The other
tool versions follow the nixpkgs lock.

## Graphify

`homeModules.graphify` provides an opt-in, isolated Python environment for stock
nixpkgs Graphify without a package overlay or extra global Python commands.
Enable it with `programs.graphify.enable = true`; customize dependencies through
`programs.graphify.package`.

When migrating from the old overlay, reinstall hooks with `graphify hook install`
in each repository after applying the new configuration. See the
[Graphify module README](home/modules/graphify/README.md) for dependency options,
hook lifecycle, and validation.

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
just check-fast               # Run all checks except full font builds
just lint                     # Run pre-commit checks
just fmt                      # Format tracked files
just update nixpkgs           # Update one flake input
```

Run `just` to list every command. `just boundary` verifies that public-repository boundaries are preserved and scans for leaked secrets.

## Source layout

`outputs/default.nix` defines the public API; `outputs/checks.nix` owns test
configurations and the check registry. Application source stays beside its
owning module rather than in a language-wide top-level directory.

Tests live under `tests/specs/{unit,integration,e2e}/`, grouped by feature with
Nix check definitions beside their test sources. Sample inputs and stubs live
in `tests/fixtures/`; shared helpers and validators live in `tests/support/`.
See [the test layout](tests/README.md) for suite boundaries and check commands.

Use Home Manager/NixOS options and Nix attribute sets for supported declarative
settings. Serialize data through Nix generators when no module option exists.
Keep shell, Zsh, Lua, Vimscript, tmux configuration, CSS, themes, and test programs
in standalone files. Home Manager's Vim wrapper loads the standalone Vimscript
through `programs.vim.extraConfig`, alongside native `programs.vim.settings`. Nix may wire commands, arguments, dependencies, environment
variables, and template values, but must not contain hand-written source programs.

Shell scripts use POSIX `#!/bin/sh`; Zsh initialization and widgets remain `.zsh`
source because they use Zsh APIs. A Bash test runner is allowed only where the
second line documents why Bash is required, such as Home Manager activation entries.
Python is retained for Python-specific tests and
terminal-control integration tests, not for shell tasks. The `posix-shell` check
runs ShellCheck and Dash or Bash syntax checks over shell sources, including package build phases.
The `zsh-syntax` check validates Zsh sources and widgets with `zsh -n`. The
`runtime-boundary` check scans production and test Nix for common embedded-source
patterns and tests its rejection rules; it is a guardrail, not a full Nix parser.

Tests wait for observable readiness instead of fixed delays and check behavior
rather than cosmetic upstream output. `module-compatibility` evaluates every
exported module with minimal fixtures, including WSL branches; `home-activation`
runs selected activation entries in a temporary home; `service-lifecycle` boots a
NixOS VM for the Compose module; and `fonts` validates built font names, tables,
glyph coverage, and text spacing. Performance guards bound expensive work and
duplicate updates instead of measuring wall-clock time.

## Desktop module

`homeModules.hyprland` configures the user-side Hyprland session, theme, remembered monitor topologies, Eww bar, Rofi, SwayNotificationCenter, Hyprlock, and Hypridle. NixOS owns installation and startup through UWSM. See [the Hyprland module README](home/modules/hyprland/README.md) for options, commands, service ownership, HDR setup, and validation.

## Private configuration

The private flake imports this repository and adds host definitions, infrastructure, secrets, and machine-specific settings. Keep those concerns outside this repository. The `boundary` check enforces that separation.
