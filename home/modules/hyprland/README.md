# Hyprland desktop module

The public Home Manager module remains `publicModules.hyprland`. NixOS installs and starts Hyprland through UWSM; this module configures the user session. Home Manager's competing Hyprland systemd integration and XWayland stay disabled.

## Module map

- `default.nix` assembles the desktop module.
- `compositor.nix` owns Lua-based Hyprland settings, generated program paths, remembered monitor topologies, display policy, and the 10-bit/HDR option.
- `lua/` contains hand-written bindings and monitor loading, plus the template for serialized Nix data.
- `theme/` owns semantic palettes, shared geometry and motion tokens, and the `desktop-theme` command.
- `shell/` owns the Quickshell bar, popups, lock screen, helper commands, and the bar's systemd-managed daemon. `shell/qml/` holds the QML sources; `shell/scripts/` holds the helpers.
- `rofi/` owns launcher, clipboard, confirmation, and power wrappers and themes.
- `notifications.nix` owns the clipboard history, the polkit agent, and keeps `dunst` disabled; the Quickshell shell is the notification daemon.
- `idle.nix` owns display blanking; `lock.nix` owns the Quickshell lock
  and its session service; `launch.nix` owns the login-shell launch into the compositor.
- `applications.nix` owns desktop-specific Ghostty and browser preferences.

## Theme

`theme/palette.nix` is the color source of truth. `theme/default.nix` exposes it through `mine.desktop.theme` and generates the design tokens the Quickshell sources read. Hyprland, Quickshell, Rofi, GTK/Qt preferences, Ghostty, and the NixOS console consume those semantic values. Ghostty uses paired light/dark themes and follows the system color scheme.

`desktop-theme` is the shared runtime interface:

```sh
desktop-theme get
desktop-theme set dark
desktop-theme set light
desktop-theme toggle
desktop-theme apply
```

The selected mode is stored under `$XDG_STATE_HOME/mineugene-desktop/theme`. Applying it updates the desktop color-scheme preference. Quickshell listens to the same state; Rofi wrappers query it before each launch. The bar canvas follows the active palette by default. Set `mine.desktop.theme.bar.trueBlack = true` for a true-black dark canvas on an OLED display; light mode still uses the light palette background. A monitor configured with `cm = "hdr"` also gets a `#000000` dark-mode canvas, regardless of `trueBlack`; light mode still uses the light palette background.

## Popup conventions

- Use **popup** for the main windows: `menu`, `profile`, `calendar`, `hardware`, `audio`, `wifi`, `ethernet`, `bluetooth`, `battery`, and `power-profile`, plus the compact `audio-output` and `audio-input` device menus. Keep window names stable. Each popup's layer namespace is `shell-<name>`.
- Compose `DesktopPopup.qml`: it owns the themed surface and anchors the window. Build the content from `PopupTitle`, `PopupSection` (a top border, title, and small-spaced children), `PopupDetail` (name and value rows), and `PopupAction` (menu rows). `ListRow` is the row for device and network lists.
- Dashboard frames use `popup.padding` (16px). Menu, profile, and audio-device frames set `compact` and pad by `spacing.small` (8px). These mouse-oriented menus use half-small (4px) row gaps. Menu rows draw on the frame surface and take `surfaceHover` under the pointer, and a row is one small step plus two pixels taller than its label. The menu and profile frames share a narrow width (20 interface-font columns); every other popup shares a wider one (30). Only headings are bold; the bar text, rows, and popup text share one size (interface size + 1). Dashboard section children keep small spacing; full audio controls keep small/normal padding (8px vertically, 16px horizontally). Popup widths are text measures: a column is one interface font size, so a larger font widens the panel with it. Device menus truncate long names and show the full label in a tooltip.
- Popups anchor to the top of the usable monitor area, below the bar's reserved height. The bar reserves its height plus `bar.outerMargin` (6px) under itself as the gap to the windows, so a top-anchored panel measures from that lower edge; `Tokens.panelTopInset` (small minus the gap) keeps the visible offset at `spacing.small` (8px), shared by the left menu, right profile, and audio-device menus and separate from internal frame padding. The anchored left or right edge carries the same `spacing.small` (8px) inset, so a popup does not touch the screen edge.
- Clicking outside an open popup dismisses it. The `Backdrop` window covers the usable area below the bar, and the bar canvas itself dismisses a popup. The canvas sits beneath the controls, so a click on a control opens its popup instead of dismissing it. A `PopupSection` with no title draws only its leading separator, which is how the Wi-Fi and Ethernet detail rows are introduced.
- Popups map and unmap; the compositor fades them. `compositor.nix` owns the fade through the `fadeLayersIn`/`fadeLayersOut` animation over the shared normal motion token (200ms) on the `default` curve, and disables the layer size and position nodes, so a popup that settles its height just after mapping does not scale. Rofi keeps `no_anim`. The bar takes the same fade when it maps.
- `radius.general` (8px) is the shared radius for Hyprland windows, bar islands, popups, and controls. `radius.small` (4px) rounds tighter insets such as calendar cells, notification images, and the compact popup rows, and the workspace cells inside a bar island, where it is concentric with the island's corner. Hyprland windows, the lock prompt, Quickshell popups and buttons, and Rofi consume these tokens. Compositor blur strength stays independent of corner geometry.
- `cornerRoundingPower` mirrors Hyprland's `decoration:rounding_power`: 1 is a straight chamfer, 2 a circular arc, and higher values squarer superellipse corners, with the radius scaled by `power / 2` so the perceived roundness holds. `compositor.nix` passes it to Hyprland, and the Quickshell bar reads it as `Tokens.cornerRoundingPower`. `CornerRectangle` (used by the islands, capsules, popups, controls, and the workspace focus and occupancy cells) and the `Ring` square meters draw the matching superellipse; circular corners keep a native `Rectangle`. The pill-shaped `VolumeSlider` stays circular.
- A workspace holding a single tiled window (`w[tv1]`) keeps that window flush with every screen edge, with the shared corner radius and a dimmed 1px focus ring. The gap above it belongs to the bar, which reserves `bar.outerMargin` below its height, so `compositor.nix` sets no top outer gap. Because that window is flush with the edges, the ring is the only cue for which window has focus, so it is kept rather than removed; it is dimmed to limit OLED edge wear. A multi-window workspace keeps the normal gap and border on the sides and bottom and the same bar-owned gap on top. `compositor.nix` owns the workspace and window rules that shape this.
- `Tokens.c` supplies the dark or light palette for the active theme mode. Add color uses there rather than choosing a mode in a component.
- The bar canvas reaches both screen edges. Its left and right sections have matching small outer insets, so menu and profile controls share the same edge spacing without widening gaps between controls. Those two controls extend their hit area to the screen corner. Cells inside an island are separated by a quarter-small (2px) gap, so the hardware rings and the status controls each read as their own tile; the workspace cells stay shoulder to shoulder.

## Shell interfaces

Runtime helpers are POSIX shell sources. Nix supplies their dependencies and
configuration through package `PATH`, environment variables, and arguments;
listener state, cleanup, and process ownership stay in the scripts. Test programs
and fixtures live under `tests/`, outside Nix strings.

Quickshell runs the bar (`bar.qml`) and the lock (`lock.qml`) as two instances of one config directory, `~/.config/quickshell/desktop`. The sources are read in place from the Nix store; the design tokens come from a generated JSON file that `SHELL_TOKENS` names. The helpers sit on the service's `PATH`, so the QML never embeds a store path. One popup is open at a time: opening another replaces it, and the state lives in the `Desktop` singleton. `quickshell ipc --path <bar.qml> call popup toggle <name>` and `... call popup close` open and close a popup from a key binding or a script.

Native Quickshell modules supply the PipeWire audio state and controls, the Hyprland workspaces and focused window, and the clock. Helpers supply what Quickshell has no module for: the iwd network state, BlueZ discovery, hardware readings, and the theme mode.

The hardware helper reads CPU, GPU, memory, storage, cooling, and uptime generically: CPU package power from hwmon or the RAPL energy counter, the GPU from `nvidia-smi` or an AMD hwmon and its DRM device, fans and pumps from labelled hwmon inputs or `liquidctl`, and storage temperatures from an `nvme` or `drivetemp` sensor. `mine.desktop.hardware` extends it for a host whose sensors the generic scan cannot name: `extraPackages` adds sensor tools to the helper's `PATH` (for example `liquidctl`), `coolingCommand` supplies an executable that prints `cpu_fan_rpm=<n>` and `aio_pump_rpm=<n>`, and `cpuPowerCommand` prints the CPU package power in watts. A host backend wins over the generic scan; omit a value to leave that reading unavailable.

The battery and power-profile cells sit to the right of the audio cells in the shared status island, after the Wi-Fi, Bluetooth, and Ethernet controls. The battery cell exists only when a battery does: `shell-power-status` reads `/sys/class/power_supply/BAT*`, refines the percent, time, and warning level through UPower when the daemon is running, and steps its glyph in ten-percent buckets while the ring follows the exact charge and carries the warning or critical tint. The power-profile cell exists only where the host enables `services.power-profiles-daemon` and the daemon answers on D-Bus: left-click is inert, right-click opens the profile dropdown, and middle-click cycles power-saver, balanced, and performance. An inhibited or degraded daemon state takes the cell's glyph.

Menu, clock, hardware, Wi-Fi, Ethernet, Bluetooth, audio, battery, profile, and notifications open on left-click. Middle-click toggles the Wi-Fi radio and the Bluetooth adapter, and toggles do not disturb on notifications. A Wi-Fi or Bluetooth control whose hardware or service is unavailable at the system level is hidden entirely. The notifications cell sits beside the session button rather than in an island, so it carries the bar's shared spacing on both sides. The active-window island shows the app name in a front capsule and the window title in a capsule behind it; the app name is removed from the title so neither part repeats the other, and the full title appears in a tooltip only when it is truncated.

The Wi-Fi, Ethernet, and Bluetooth tooltips share one grammar: `<identity> · <status>`. The identity is the link name when there is one (SSID or connection name) and the interface or adapter name otherwise; the status is one lowercase token from `connected`, `no internet`, `connecting`, `disconnected`, `enabled`, `disabled`, `unavailable`. The kind label (`Wi-Fi`, `Ethernet`, `Bluetooth`) replaces the identity only when the link has no name at all. A control's tooltip is empty while its own popup is open.

For each audio meter, left-click opens the full audio controls, middle-click toggles that stream's mute, and scrolling adjusts its volume. Right-click opens a compact default-device menu: outputs for the speaker, inputs for the microphone. The current default has a check mark; selecting another makes it the PipeWire default and dismisses the menu. An empty list shows “No devices available”. These are PipeWire defaults; the full audio popup keeps its default-device sections and renders a downstream extension under its `Mixer` heading.

Quickshell is the notification daemon: it owns `org.freedesktop.Notifications`, so no other daemon may run. The newest five notifications stack as toasts under the bar (layer `shell-notification`); a toast times out after 8 seconds (5 for low urgency, or the sender's own timeout) and never for critical ones, and hovering it holds it. Every notification stays in the history until dismissed, and the panel (`notifications`) lists it with its actions, a close button, and "Dismiss all". Clicking a notification runs its default action and dismisses it; middle- or right-click dismisses it. While do not disturb is on, new notifications skip the toasts and wait in the panel. History and the do-not-disturb flag live in memory only, so a restart of the shell clears the history (a reload keeps it).

The `shell-menu` command backs compositor reload, terminal, force-quit, process-manager, and focused-window actions from the menu popup, and the menu toggles the theme. The force-quit action opens a Rofi picker (`ui-kill`) over the open Hyprland windows and sends `SIGTERM` to the chosen window's process. The process-manager action, "Open top", opens `btm` in a floating Ghostty window. The profile popup offers session and power actions through `ui-power`, hiding hibernate when unavailable. Each row starts `ui-power` detached, so it outlives the popup while its confirmation waits. A confirmation highlights No over the affirmative action and accepts a single click, so neither Enter nor a quick click commits the action by reflex.

The audio popup controls the default PipeWire sink and source under `Output` and `Input` headings, and a `Mixer` heading holds a downstream extension. Each stream takes a fixed square mute button beside its slider and volume: the speaker shows `EEE8` while muted and the level glyphs `f026`/`f027`/`efcf`/`f028`, the microphone `f130`/`f131`. A full-width chevron row expands the default-device list (`f0da` closed, `f0d7` open) and names the current default below it while collapsed; the rows elide long names, and the input list omits sink monitors, which the session manager will not keep as a capture default. Device names are shown as PipeWire reports them. The bar reads their state from PipeWire directly, so hardware mutes and knob turns show on the next event instead of the next poll. The microphone cell in the bar exists while a default source does, and its glyph states mute. The `shell-audio` command remains for key bindings (`change-sink`, `toggle-sink`, and the like). `mine.desktop.audio.extension` attaches a downstream popup section and its helper packages: the popup renders `AudioExtension.qml` from the supplied source directory under the `Mixer` heading, and the packages join the shell's `PATH`. An unset extension leaves the popup PipeWire-only. The Bluetooth popover toggles the adapter, makes it discoverable and pairable while the popover is open, and lists nearby devices through `shell-bluetooth`, the Wi-Fi popover toggles its radio, scans, and lists visible networks through `shell-network-listener`, and the Ethernet popover reports the wired link. This module consumes a network stack; it does not provide one. A downstream host enables `nixosModules.iwd-networkd` (iwd association, systemd-networkd addressing, systemd-resolved) or another composition that exposes iwd's D-Bus API.

The Wi-Fi list shows the six strongest networks, and a "Show more" control opens the full list in a Rofi menu; the Bluetooth list groups devices into paired-and-online, paired-and-offline, and discovered, caps only the discovered group at six, and offers the same control for the rest. The Bluetooth popover broadcasts only while it is open: opening it sets the adapter discoverable and pairable and shows a notice naming it, and any close -- a dismissal or a replacement -- turns broadcasting off. A detached watchdog restores the adapter if that close never runs, so a crashed bar cannot leave the machine discoverable. The menus share the power dialogs' base theme but align their rows to the leading edge, do not cycle, and exit on a click outside. Both lists are watched through a helper that does no list work while nothing is scanning and emits only on change, so an idle popup neither polls the stack nor rebuilds its rows under the pointer; the shell starts and stops the helper with the popup, so nothing runs while it is closed. The reload control reads "Scanning for networks" or "Scanning for devices" (and is disabled) until the helper's own scan marker clears, and opening either popup starts one. Selecting a network connects to it, and "Add network" collects a hidden or custom SSID with its security. A secured network that is not yet known prompts for a passphrase through Rofi, which returns the value to the helper rather than interpolating it into a shell command; a row selects by list position, never by SSID or device name, for the same reason. Privileged `iwd` actions run through `pkexec` and the session's polkit agent; the NixOS `iwd-networkd` module enables the setuid wrapper they need. The actions that wait on a dialog or on the adapter run detached from the shell.

Rofi entry points are:

- `ui-launcher`
- `ui-clipboard`
- `ui-confirm` with `MESSAGE [AFFIRMATIVE]`
- `ui-kill`
- `ui-power`

All wrappers select the current generated Rofi theme and use Nix-resolved tools. Each wrapper resolves the primary monitor through `monitor-topology primary` and passes it as `-monitor`, so the launcher follows the monitor layout without a connector name in configuration.

## Service ownership

Long-running session processes have one Home Manager user-service owner:

- `quickshell.service`: the Quickshell bar and popups
- `hypridle.service`: idle listener
- `shell-lock.service`: session lock, started with the compositor session
- `monitor-topology.service`: monitor topology detection, restoration, and persistence

`desktop-theme.service` is a one-shot theme application service. Hyprland has no duplicate startup hooks for these processes. The NixOS module keeps `programs.hyprland.withUWSM = true`; Home Manager keeps `wayland.windowManager.hyprland.systemd.enable = false`.

## Boot to a locked session

`mine.desktop.hyprland.launchFromTty` (off by default) writes a guarded block into the login shell profile that starts Hyprland through UWSM when the shell is on `launchTty` (default `tty1`) and no Wayland display is set. The NixOS `getty-autologin` module supplies the matching `getty@<tty>` autologin drop-in; see its README for options and the rollback to a plain TTY login. The lock autostarts unconditionally as `shell-lock.service`, so an autologged-in session is locked as soon as it appears.

## Idle policy

Hypridle blanks displays after 10 minutes and restores them on activity, and
locks the session through `shell-lock.service` after 15 minutes. It never suspends
or hibernates the system; `before_sleep_cmd` locks the session if the system is
suspended by another means. `shell-lock.service` runs `lock.qml`, a second
Quickshell instance that holds an `ext-session-lock` and authenticates against
the `shell-lock` PAM service, which the NixOS side provides. It starts before
the other session surfaces, so an autologged-in session is locked as soon as it
appears. A clean unlock exits successfully and the service stays stopped; any
other exit leaves the compositor locked and restarts the service, which locks
again. `misc.allow_session_lock_restore` lets that fresh lock replace one whose
client died without unlocking. The unit is not enabled through `WantedBy`:
sd-switch starts every unit an active target wants on each switch, which would
lock an unlocked session, so the target starts it from an enable link in the
data directory instead. `X-SwitchMethod = "keep-old"` keeps a running lock up
when a switch rewrites the unit. The lock draws its prompt only on the primary
monitor, resolved at launch through `monitor-topology primary`; the other
monitors stay a plain background while the session remains locked. The `lock`
command (`shell-lock`) starts the service.

## Remembered monitor topologies

Hyprland restores an exact saved topology through its `monitor.added` event, emitted after each output completes setup. `monitor-topology.service` polls only to save stable changes to mode, refresh rate, position, scale, or transform. Applying a profile does not trigger a save loop. A Hyprland configuration reload also reapplies the saved profile before the watcher can mistake compositor defaults for a user change.

Profiles are per-user state in `$XDG_STATE_HOME/monitor-topologies/layouts.json`, falling back to `~/.local/state/monitor-topologies/layouts.json`. The directory and file use modes `0700` and `0600`. Displays are matched by make, model, and serial; the description is a fallback for displays without a serial. Connector names such as `DP-1` are deliberately not persisted.

Commands are:

```sh
monitor-topology apply
monitor-topology save
monitor-topology primary
```

`save` also records the currently focused monitor as the profile's primary monitor. Applying a profile waits only until Hyprland reports that profile's monitor rules active, then focuses that monitor and places the cursor on it. The wait is bounded by `MONITOR_TOPOLOGY_APPLY_DEADLINE_SECONDS` (default 10) so a layout that never becomes active cannot spin forever; on expiry `apply` warns and exits non-zero. Automatic saves preserve that selection rather than changing it whenever focus moves. `primary` prints the current output name of that recorded monitor, falling back to the first connected monitor; the bar and the Rofi wrappers call it so they target the primary without naming a connector in configuration.

## Reloading after a rebuild

Hyprland's Lua configuration is reloaded only when something asks it to; a Home Manager activation that changes `generated/programs.lua` leaves the running bindings pointing at the previous store paths until a reload. Setting `mine.desktop.hyprland.reloadOnActivation = true` runs `hyprctl reload` from the activation hook, ordered after `linkGeneration`. It is off by default.

The hook discovers the live instance through `hyprctl instances` (`HYPRLAND_INSTANCE_SIGNATURE` is not in the activation environment) and skips silently at boot or when no instance is running. It records a fingerprint of the generated Hyprland files in `$XDG_STATE_HOME/hyprland-activation` and reloads only when that fingerprint changes, so unrelated switches do not reload. Note that a reload re-applies the remembered monitor layout, which focuses the primary monitor and moves the pointer to it.

## HDR and 10-bit output

`mine.desktop.display.monitors` in `compositor.nix` is hardware-specific. When downstream configuration supplies verified output names, modes, refresh rates, and scales, the generated Lua monitor rules enable 10-bit output, one rule per display. Each rule defaults to `cm = "auto"`: a wide-gamut SDR desktop where `render:cm_auto_hdr` may switch to HDR for fullscreen HDR surfaces. A display can override its preset (including `hdr` for a permanent HDR desktop) after validating that screenshots and screen sharing stay usable under it; SDR content is tone-mapped with `sdrSaturation` left at its default unless tuning is wanted. Positions are deliberately not declared; `monitor-topology.service` restores the remembered arrangement after the rules apply.

On a permanent `hdr` display, Hyprland maps SDR content through per-monitor `sdrSaturation`, `sdrMinLuminance`, and `sdrMaxLuminance`; SDR brightness stays at Hyprland's default. The defaults (`1`, `0.2` nits, `80` nits) render SDR windows dim and desaturated on bright panels: 80-nit reference white is a small fraction of peak. Validated values on an AW2725DF (QD-OLED, ~1000-nit peak): `sdrSaturation = 1.05`, `sdrMinLuminance = 0.005`, `sdrMaxLuminance = 250`. Tune by live `hyprctl eval` before committing.

To roll back a bad display policy, empty the downstream `mine.desktop.display.monitors` list, then rebuild from a text console or a prior generation. The option and generated monitor rules live in `home/modules/hyprland/compositor.nix`. Do not guess connector names or mode values.

## Font rendering

`environment.nix` pins fontconfig rendering to antialiasing on, `hintslight`, and `rgba = none`. Grayscale antialiasing is the safe choice for the panels this desktop targets: wide-gamut OLED displays use non-stripe subpixel layouts where subpixel rendering produces color fringing, and a portrait-rotated panel would need a vertical ordering. `lcdfilter` stays at the system default, which has no effect while subpixel rendering is off. The values use `lib.mkDefault`, so a downstream host with a standard RGB-stripe display can select `fonts.fontconfig.subpixelRendering = "rgb"` without a conflicting definition.

`mine.desktop.theme.fonts` selects the interface (sans), serif, and monospace families and installs their packages. The interface role defaults to the `ibm-plex` package's `sans-condensed` family (`IBM Plex Sans Condensed`, rendered with the slashed-zero `zero` feature), the serif role to its `serif` family (`IBM Plex Serif`), and the monospace role to the prebuilt SS04 release renamed to `Iosevka`, `Iosevka Term`, and `Iosevka Fixed`. `nerd-fonts.symbols-only` installs alongside, and Ghostty lists `Symbols Nerd Font Mono` as a fallback family, so icon codepoints the Iosevka families lack resolve to it. Downstream hosts may override any of the three packages, for example to supply a different sans or serif build.

## Validation

Run from the public repository root:

```sh
just lint
just boundary
just check
nix build .#checks.x86_64-linux.shell-scripts
nix build .#checks.x86_64-linux.quickshell
nix build .#checks.x86_64-linux.hyprland-lua
nix build .#checks.x86_64-linux.getty-autologin
```

The shell-scripts check runs the helper commands against stubs without GUI packages. The quickshell check lints every QML source, validates the generated design tokens, and reads the bar and lock unit definitions and the PAM service the lock needs. Neither starts a compositor. The Lua check runs `Hyprland --verify-config` against the actual Home Manager-generated entrypoint and imported files. The getty-autologin check reads the generated `getty@tty1.service` unit and the login-profile launch guard.

Before rebooting, build the downstream NixOS host without activating it. Inspect the generated configuration, then validate the running session:

```sh
nixos-rebuild build --flake /path/to/private-flake#host
hyprctl configerrors
```

Only switch after both pass. From a recoverable TTY, verify that TTY1 reaches a locked Hyprland session and that TTY2 still shows a login prompt before rebooting. The checks do not exercise the lock, so also confirm that a correct password unlocks, a wrong one does not, and that killing `shell-lock.service` leaves the screen locked and brings the lock back. After activation, also verify each popup in both theme modes, its padding, row separation, corner radius, and text wrapping, the bar's edge spacing and click bindings, the 10-minute display blank, screen capture/sharing, hardware-specific HDR behavior, one running instance of each user daemon, and no new failed system or user services.
