# Hyprland desktop module

The public Home Manager module remains `publicModules.hyprland`. NixOS installs and starts Hyprland through UWSM; this module configures the user session. Home Manager's competing Hyprland systemd integration and XWayland stay disabled.

## Module map

- `default.nix` assembles the desktop module.
- `compositor.nix` owns Lua-based Hyprland settings, generated program paths, remembered monitor topologies, display policy, and the 10-bit/HDR option.
- `lua/` contains hand-written bindings and monitor loading.
- `theme/` owns semantic palettes, shared geometry and motion tokens, and the `desktop-theme` command.
- `eww/` owns the bar, popovers, listeners, and their systemd-managed daemon.
- `rofi/` owns launcher, clipboard, confirmation, and power wrappers and themes.
- `notifications.nix` and `swaync/` own SwayNotificationCenter configuration and styling.
- `idle.nix` owns display blanking; `lock.nix` owns Hyprlock.
- `applications.nix` owns desktop-specific Ghostty and browser preferences.

## Theme

`theme/palette.nix` is the color source of truth. `theme/default.nix` exposes it through `mine.desktop.theme` and generates SCSS and Rasi tokens. Hyprland, Eww, Rofi, SwayNC, GTK/Qt preferences, Ghostty, Hyprlock, and the NixOS console consume those semantic values. Ghostty uses paired light/dark themes and follows the system color scheme.

`desktop-theme` is the shared runtime interface:

```sh
desktop-theme get
desktop-theme set dark
desktop-theme set light
desktop-theme toggle
desktop-theme apply
```

The selected mode is stored under `$XDG_STATE_HOME/mineugene-desktop/theme`. Applying it updates the desktop color-scheme preference and SwayNC CSS. Eww listens to the same state; Rofi wrappers query it before each launch.

## Shell interfaces

Eww opens the `bar` window. Its popovers are `calendar`, `hardware`, `menu`, `audio`, and `network`. `popup-toggle` accepts one popover name, closes peer popovers, and toggles the requested one. The `eww-menu` command backs compositor reload, virtual-terminal, terminal, process-manager, and focused-window actions from the menu popover. Switching to virtual terminal 2 requests polkit authorization; the process-manager action opens `btop` in a floating Ghostty window. The audio popover controls the default WirePlumber sink and source. The network listener uses an existing NetworkManager service when available; this module does not enable NetworkManager.

Rofi entry points are:

- `ui-launcher`
- `ui-clipboard`
- `ui-confirm` with `MESSAGE [AFFIRMATIVE]`
- `ui-power`

All wrappers select the current generated Rofi theme and use Nix-resolved tools.

## Service ownership

Long-running session processes have one Home Manager user-service owner:

- `eww.service`: Eww daemon and the bar
- `swaync.service`: notification daemon and control center
- `hypridle.service`: idle listener
- `monitor-topology.service`: monitor topology detection, restoration, and persistence

`desktop-theme.service` is a one-shot theme application service. Hyprland has no duplicate startup hooks for these processes. The NixOS module keeps `programs.hyprland.withUWSM = true`; Home Manager keeps `wayland.windowManager.hyprland.systemd.enable = false`.

## Idle policy

Hypridle blanks displays after 10 minutes and restores them on activity. It does not suspend or hibernate the system.

## Remembered monitor topologies

Hyprland restores an exact saved topology through its `monitor.added` event, emitted after each output completes setup. `monitor-topology.service` polls only to save stable changes to mode, refresh rate, position, scale, or transform. Applying a profile does not trigger a save loop. A Hyprland configuration reload also reapplies the saved profile before the watcher can mistake compositor defaults for a user change.

Profiles are per-user state in `$XDG_STATE_HOME/monitor-topologies/layouts.json`, falling back to `~/.local/state/monitor-topologies/layouts.json`. The directory and file use modes `0700` and `0600`. Displays are matched by make, model, and serial; the description is a fallback for displays without a serial. Connector names such as `DP-1` are deliberately not persisted.

Commands are:

```sh
monitor-topology apply
monitor-topology save
```

`save` also records the currently focused monitor as the profile's primary monitor. Applying a profile waits only until Hyprland reports that profile's monitor rules active, then focuses that monitor and places the cursor on it. Automatic saves preserve that selection rather than changing it whenever focus moves.

## HDR and 10-bit output

`mine.desktop.display.monitors` in `compositor.nix` is hardware-specific. When downstream configuration supplies verified output names, modes, refresh rates, and scales, the generated Lua monitor rules enable 10-bit output, one rule per display. Each rule defaults to `cm = "auto"`: a wide-gamut SDR desktop where `render:cm_auto_hdr` may switch to HDR for fullscreen HDR surfaces. A display can override its preset (including `hdr` for a permanent HDR desktop) after validating that screenshots and screen sharing stay usable under it; SDR content is tone-mapped with `sdrBrightness`/`sdrSaturation` left at defaults unless tuning is wanted. Positions are deliberately not declared; `monitor-topology.service` restores the remembered arrangement after the rules apply.

On a permanent `hdr` display, Hyprland maps SDR content through per-monitor `sdrBrightness`, `sdrSaturation`, `sdrMinLuminance`, and `sdrMaxLuminance`. The defaults (`1`, `1`, `0.2` nits, `80` nits) render SDR windows dim and desaturated on bright panels: 80-nit reference white is a small fraction of peak. Validated values on an AW2725DF (QD-OLED, ~1000-nit peak): `sdrSaturation = 1.05`, `sdrMinLuminance = 0.005`, `sdrMaxLuminance = 250`, with `sdrBrightness` left at its default. Tune by live `hyprctl eval` before committing.

To roll back a bad display policy, empty the downstream `mine.desktop.display.monitors` list, then rebuild from a text console or a prior generation. The option and generated monitor rules live in `home/modules/hyprland/compositor.nix`. Do not guess connector names or mode values.

## Validation

Run from the public repository root:

```sh
just lint
just boundary
just check
nix build .#checks.x86_64-linux.hyprland-lua
nix build .#checks.x86_64-linux.hyprland-nvidia
```

The Lua check runs `Hyprland --verify-config` against the actual Home Manager-generated entrypoint and imported files. The NVIDIA check exercises the greeter scripts and parses the generated Wayfire and Eww configuration.

Before rebooting, build the downstream NixOS host without activating it. Inspect the generated configuration, then validate the running session:

```sh
nixos-rebuild build --flake /path/to/private-flake#host
hyprctl configerrors
```

Only switch after both pass. From a recoverable TTY, restart greetd and verify ReGreet, login, and the UWSM session before rebooting. After activation, also verify each popover, theme switching, the 10-minute display blank, screen capture/sharing, hardware-specific HDR behavior, one running instance of each user daemon, and no new failed system or user services.
