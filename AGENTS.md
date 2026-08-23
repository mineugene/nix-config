# AGENTS.md

## Scope

This is the public, reusable half of a Nix flake. It exports Home Manager and NixOS modules, an overlay, and checks. It is **not** a complete host configuration. Keep hosts, infrastructure, SOPS material, and personal composition in the private flake.

Do not assume a checkout path. Start from the repository root (`git rev-parse --show-toplevel`) and inspect `git remote -v` when repository identity matters. The published flake input is `github:mineugene/nix-config`.

`graphify-out/` and `.direnv/` are ignored generated state, not sources of truth. Do not edit or use Graphify output for navigation.

## Navigate

Read `flake.nix`, then `outputs/default.nix`. The latter is the export index, composition root, and check registry.

| Task                                           | Start here                                                                  |
| ---------------------------------------------- | --------------------------------------------------------------------------- |
| Exported Home Manager module                   | `outputs/default.nix` -> `home/modules/<name>/`                             |
| Shared user defaults                           | `home/users/shared/main.nix`                                                |
| Desktop/Hyprland, theme, Eww, Rofi, lock, idle | `home/modules/hyprland/README.md`, then `default.nix` and its imported file |
| Exported NixOS module                          | `outputs/default.nix` -> `nixos/modules/<name>/default.nix`                 |
| Package patch or custom package                | `overlays/default.nix`, then its named subdirectory                         |
| Regression check                               | matching `tests/*.nix`, wired from `outputs/default.nix`                    |
| User-facing contract                           | `README.md`                                                                 |

`outputs/default.nix` explicitly maps module names to paths. When adding, removing, or renaming an exported module, update that map and any matching check; there is no automatic module discovery. Preserve its public output names unless the task calls for an API change.

## Public boundary

- Do not add `hosts/`, `infra/`, `secrets/`, `.sops.yaml`, machine identifiers, or private deployment data here.
- Keep reusable modules parameterized; host-specific choices belong downstream.
- `just boundary` runs Gitleaks and rejects private-repository paths. Run it for boundary-sensitive work.
- Read the nearby module README before changing an operational subsystem. In particular, the Hyprland README defines service ownership and hardware/HDR constraints.

## Runtime code

- Keep declarative configuration and dependency wiring in Nix. Put control flow, process lifecycle, cleanup, and diagnostics in standalone scripts.
- New shell scripts use `#!/bin/sh` and POSIX syntax unless Bash is required and documented.
- Package simple source scripts with `lib/scripts.nix`. If `writeShellApplication` is needed for runtime inputs, keep its `text` to `builtins.readFile` plus environment wiring. Do not add substantial programs through `writeShellScript`, `writeShellScriptBin`, or `sh -c` strings.
- Supply dynamic values as arguments or environment variables and dependencies through service/package `PATH` rather than substituting store paths into scripts.
- Every `#!/bin/sh` file must pass `shellcheck --shell=sh` and `dash -n` through the `posix-shell` flake check.

## Validate

Run commands from the repository root:

```sh
just lint                         # formatting and pre-commit checks
just boundary                     # public/secrets boundary
just check                        # all flake checks
nix build .#checks.x86_64-linux.<check-name>
```

`just fmt` rewrites tracked files, so use it when formatting changes are intended. Nix uses four-space `nixfmt` indentation. `just update [input...]` changes `flake.lock`; do not update inputs incidentally.

## Relationship to the private flake

A separate private flake consumes these exports through its `public` input and owns host composition. It may be checked against an unpublished public checkout with an explicit flake input override. Never assume a sibling directory exists or that a private Forgejo remote is reachable; discover any checkout or remote at runtime and pass its path explicitly.
