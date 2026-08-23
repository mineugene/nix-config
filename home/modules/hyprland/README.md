# Hyprland desktop module

The public Home Manager module remains `publicModules.hyprland`. NixOS installs and starts Hyprland through UWSM; this module configures the user session. Home Manager's competing Hyprland systemd integration and XWayland stay disabled.

## Module map

- `default.nix` assembles the desktop module.
- `compositor.nix` owns Lua-based Hyprland settings, generated program paths, remembered monitor topologies, display policy, and the 10-bit/HDR option.
- `lua/` contains hand-written bindings and monitor loading, plus the template for serialized Nix data.
- `theme/` owns semantic palettes, shared geometry and motion tokens, and the `desktop-theme` command.
- `eww/` owns the bar, popups, listeners, and their systemd-managed daemon.
- `rofi/` owns launcher, clipboard, confirmation, and power wrappers and themes.
- `notifications.nix` and `swaync/` own SwayNotificationCenter configuration and styling.
- `idle.nix` owns display blanking; `lock.nix` owns Hyprlock.
- `applications.nix` owns desktop-specific Ghostty and browser preferences.

## Theme

`theme/palette.nix` is the color source of truth. `theme/default.nix` exposes it through `mine.desktop.theme` and generates SCSS tokens. Hyprland, Eww, Rofi, SwayNC, GTK/Qt preferences, Ghostty, Hyprlock, and the NixOS console consume those semantic values. Ghostty uses paired light/dark themes and follows the system color scheme.

`desktop-theme` is the shared runtime interface:

```sh
desktop-theme get
desktop-theme set dark
desktop-theme set light
desktop-theme toggle
desktop-theme apply
```

The selected mode is stored under `$XDG_STATE_HOME/mineugene-desktop/theme`. Applying it updates the desktop color-scheme preference and SwayNC CSS. Eww listens to the same state; Rofi wrappers query it before each launch. The bar canvas follows the active palette by default. Set `mine.desktop.theme.bar.trueBlack = true` for a true-black dark canvas on an OLED display; light mode still uses the light palette background.

## Popup conventions

- Use **popup** for the main Eww windows: `menu`, `profile`, `calendar`, `hardware`, `audio`, and `network`, plus the compact `audio-output` and `audio-input` device menus. Keep window names, namespaces, and commands stable.
- Compose `eww/config/popups/common.yuck`: `popup-frame` owns the themed surface; `popup-action` supplies menu rows; `popup-detail` supplies name/value rows; `popup-title` supplies headings; `popup-section` supplies a top border, title, and small-spaced children. Put dynamic `for` lists inside a concrete `box` before passing them as children.
- Dashboard frames use `popup.padding` (24px). Menu, profile, and audio-device frames use the `compact` class with `spacing.small` padding (8px). These mouse-oriented menus use half-small/small row padding (4px vertically, 8px horizontally) and half-small row gaps (4px). Dashboard section children keep small spacing; full audio controls keep small/normal padding (8px vertically, 16px horizontally). Popup widths remain text measures; device menus truncate long names with the full label in a tooltip.
- Popups anchor to the top of the usable monitor area, below the bar's exclusive zone. Their top offset is `spacing.small` (8px), shared by the left menu, right profile, and audio-device menus; it is separate from internal frame padding. Eww adds each window name as a CSS class on the window content, so `window > .menu` resets GTK Adwaita's `.menu` margin.
- Surfaces and popup buttons share the active-workspace circle's visible radius. `radius.card` is `(bar.height - 2 * spacing.small) / 2`: a 22px marker gives an 11px radius. `radius.small` follows it. Hyprland windows, Hyprlock, Eww popups and buttons, Rofi, and SwayNC consume these tokens. `radius.pill` (999px) is reserved for fully round bar islands, workspace markers, meters, and slider caps; it is not a literal window radius. Compositor blur strength stays independent of corner geometry.
- `popup-theme` supplies both dark and light popup colors, like `bar-theme` does for the bar. Add color rules there rather than duplicating mode-specific selectors.
- The bar canvas reaches both screen edges. Its left and right sections have matching small outer insets, so menu and profile controls share the same edge spacing without widening gaps between controls.

## Shell interfaces

Runtime helpers are POSIX shell sources. Nix supplies their dependencies and
configuration through package `PATH`, environment variables, and arguments;
listener state, cleanup, and process ownership stay in the scripts. Test programs
and fixtures live under `tests/`, outside Nix strings.

Eww opens the `bar` window. `popup-toggle` accepts one popup name, closes peer popups, and toggles the requested one. It detaches itself from eww's 200ms widget-command timeout and closes only the windows that are open, so a busy CPU cannot kill a toggle mid-run; concurrent runs serialise on a lock so rapid clicks always resolve to one popup, and the bar dims its controls for the duration of a run.

Menu, clock, hardware, network, audio, profile, and notifications open on left-click. Notification right-click toggles do not disturb. Bluetooth and theme controls keep their direct left-click actions.

For each audio circle, left-click opens the full audio controls, middle-click toggles that stream's mute, and scrolling adjusts its volume. Right-click opens a compact default-device menu: outputs for the speaker, inputs for the microphone. The current default has a check mark; selecting another calls `eww-audio set-default` and dismisses the menu only on success. An empty list shows “No devices available”. These are PipeWire defaults, separate from OpenXLR monitor routing; the full audio popup retains both its default-device sections and monitor controls.

The `eww-menu` command backs compositor reload, terminal, process-manager, and focused-window actions from the menu popup. The process-manager action opens `btm` in a floating Ghostty window. The profile popup offers session and power actions through `ui-power`, hiding hibernate when unavailable.

The audio popup controls the default WirePlumber sink and source. The bar's audio state comes from `eww-audio listen`, which emits the shared status on PipeWire-pulse events instead of a poll, so hardware mutes and knob turns show on the next event. The `eww-audio` monitor commands (`monitor-status`, `set-monitor`, `cycle-monitor`) read and switch OpenXLR's monitor output through the daemon's HTTP API, using the sinks configured in `mine.desktop.audio.monitorOutputs`; an empty list leaves them degraded to an unavailable response and the rest of the helper untouched. The network listener uses an existing NetworkManager service when available; this module does not enable NetworkManager.

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

`mine.desktop.display.monitors` in `compositor.nix` is hardware-specific. When downstream configuration supplies verified output names, modes, refresh rates, and scales, the generated Lua monitor rules enable 10-bit output, one rule per display. Each rule defaults to `cm = "auto"`: a wide-gamut SDR desktop where `render:cm_auto_hdr` may switch to HDR for fullscreen HDR surfaces. A display can override its preset (including `hdr` for a permanent HDR desktop) after validating that screenshots and screen sharing stay usable under it; SDR content is tone-mapped with `sdrSaturation` left at its default unless tuning is wanted. Positions are deliberately not declared; `monitor-topology.service` restores the remembered arrangement after the rules apply.

On a permanent `hdr` display, Hyprland maps SDR content through per-monitor `sdrSaturation`, `sdrMinLuminance`, and `sdrMaxLuminance`; SDR brightness stays at Hyprland's default. The defaults (`1`, `0.2` nits, `80` nits) render SDR windows dim and desaturated on bright panels: 80-nit reference white is a small fraction of peak. Validated values on an AW2725DF (QD-OLED, ~1000-nit peak): `sdrSaturation = 1.05`, `sdrMinLuminance = 0.005`, `sdrMaxLuminance = 250`. Tune by live `hyprctl eval` before committing.

To roll back a bad display policy, empty the downstream `mine.desktop.display.monitors` list, then rebuild from a text console or a prior generation. The option and generated monitor rules live in `home/modules/hyprland/compositor.nix`. Do not guess connector names or mode values.

## Validation

Run from the public repository root:

```sh
just lint
just boundary
just check
nix build .#checks.x86_64-linux.eww-runtime
nix build .#checks.x86_64-linux.eww
nix build .#checks.x86_64-linux.swaync
nix build .#checks.x86_64-linux.hyprland-lua
nix build .#checks.x86_64-linux.hyprland-nvidia
```

The Eww runtime check runs listener and hardware helpers against stubs without GUI packages. The full Eww check also validates bar configuration and opens every window under Xvfb. The SwayNC check validates the generated configuration against the upstream schema. The Lua check runs `Hyprland --verify-config` against the actual Home Manager-generated entrypoint and imported files. The NVIDIA check exercises the greeter scripts and parses the generated Wayfire and Eww configuration.

Before rebooting, build the downstream NixOS host without activating it. Inspect the generated configuration, then validate the running session:

```sh
nixos-rebuild build --flake /path/to/private-flake#host
hyprctl configerrors
```

Only switch after both pass. From a recoverable TTY, restart greetd and verify ReGreet, login, and the UWSM session before rebooting. After activation, also verify each popup in both theme modes, its padding, row separation, corner radius, and text wrapping, the bar's edge spacing and click bindings, the 10-minute display blank, screen capture/sharing, hardware-specific HDR behavior, one running instance of each user daemon, and no new failed system or user services.
