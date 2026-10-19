# Getty autologin module

`nixosModules.getty-autologin` autologins one user on one virtual terminal and
leaves every other terminal showing a login prompt. It sets only the exec line
of the `getty@<tty>.service` instance, so the rest of the NixOS getty template
stays in place.

## Options

- `mine.autologin.user`: the user logged in automatically. `null` (the default)
  leaves the normal login prompt, so the module is inert until a host sets it.
- `mine.autologin.tty`: the terminal that autologins. Defaults to `tty1`.

The global `services.getty.autologinUser` option is deliberately not used:
it autologins every `getty@` and `autovt@` instance, so a VT switch to TTY2
would also skip the login prompt. The instance drop-in keeps TTY2 usable as a
recovery login.

## Pairing with a session launch

The companion Home Manager option `mine.desktop.hyprland.launchFromTty` starts
Hyprland from the login shell profile, guarded to the same terminal and to
sessions with no Wayland display. Enable both for a boot straight to a locked
session, or neither for a normal login.

## Rollback to the default TTY login

To fall back to a plain console login:

1. Set `mine.autologin.user = null` (or remove the module import) and
   `mine.desktop.hyprland.launchFromTty = false`.
2. Rebuild and reboot. TTY1 shows a normal login prompt.
3. Log in at the prompt and start Hyprland by hand:

    ```sh
    uwsm start -e -D Hyprland hyprland.desktop
    ```

The Quickshell lock still autostarts as a user service, so a manual start shows one extra
password prompt after the console login. That is expected for the recovery path.
