{ lib, pkgs, ... }:
let
    mkPosixScript = import ../../../lib/scripts.nix { inherit pkgs; };
    shortenPath = mkPosixScript {
        name = "shorten-path";
        src = ./scripts/shorten-path.sh;
    };
    displayName = mkPosixScript {
        name = "tmux-display-name";
        src = ./scripts/display-name.sh;
    };
    yubikeyTouch = mkPosixScript {
        name = "yubikey-touch-indicator";
        src = ./scripts/yubikey-touch-indicator.sh;
    };
    # --- Tokyo Night palette ---
    base = "#1a1b26";
    overlay = "#0c0e14";
    muted = "#565f89";
    subtle = "#a9b1d6";
    text = "#c0caf5";
    sakura = "#f7768e";
    honey = "#e0af68";
    ember = "#ff9e64";
    jade = "#73daca";
    glacier = "#7dcfff";
    wisteria = "#bb9af7";

    # Bg-dominant flag precedence: bell > activity > base. Active/inactive differ only in base bg + fg.
    # @yk-touching pre-empts the active branch (sakura bg) while a YubiKey touch is pending; notify.sh toggles it.
    inactiveBg = "#{?window_bell_flag,${sakura},#{?window_activity_flag,${glacier},${base}}}";
    inactiveFg = "#{?window_bell_flag,${base},#{?window_activity_flag,${base},${muted}}}";
    activeBg = "#{?#{==:#{E:@yk-touching},1},${sakura},#{?window_bell_flag,${sakura},#{?window_activity_flag,${glacier},${overlay}}}}";
    activeFg = "#{?#{==:#{E:@yk-touching},1},${base},#{?window_bell_flag,${base},#{?window_activity_flag,${base},${text}}}}";

    # Resolved + tail-truncated display name (shortenPath for zsh windows, raw #W otherwise; cap 32 chars w/ leading ...).
    name = ''#(${lib.getExe displayName} "#W" "#{pane_current_path}")'';
in
{
    imports = [
        ./aliases.nix
        ./keymap.nix
    ];

    home.packages = [
        displayName
        shortenPath
        yubikeyTouch
    ];

    programs.tmux = {
        enable = true;

        prefix = "C-s";
        keyMode = "vi";

        aggressiveResize = true;
        baseIndex = 1;
        clock24 = true;
        disableConfirmationPrompt = false;
        escapeTime = 0;
        focusEvents = true;
        historyLimit = 9999;
        mouse = false;
        sensibleOnTop = true;
        terminal = "tmux-256color";

        extraConfig = ''
            # --- Truecolour passthrough ---
            # Outer terminfo (xterm-256color and friends) rarely declares the RGB cap,
            # so programs inside the pane fall back to the 256-colour palette and the
            # Tokyo Night statusline renders downsampled.
            # Advertise RGB for the outer terms actually in use (any *256color terminal,
            # Ghostty's own terminfo, and tmux's inner term itself) so tmux passes 24-bit
            # escapes through unmolested. tmux-256color (inner TERM, set above) already
            # declares RGB natively; the explicit entry below covers nested-tmux cases.
            set -as terminal-features ',*256color:RGB'
            set -as terminal-features ',xterm-ghostty:RGB'
            set -as terminal-features ',tmux-256color:RGB'

            # --- General ---
            set -g extended-keys on
            set -g extended-keys-format csi-u
            set -g detach-on-destroy on
            set -g renumber-windows on
            set -g pane-base-index 1
            set -g bell-action none
            set -g repeat-time 300
            set -gw automatic-rename on
            set -g mode-style bg=brightblack,fg=default

            # --- Status bar ---
            # The Tokyo Night base background matches the terminal for a seamless edge;
            # subtle foreground is the global default.
            set -g status-style 'fg=${subtle},bg=${base}'
            set -g status-position top
            set -g status-justify left
            set -g status-left-length 40
            set -g status-right-length 160
            set -g status-interval 1

            # --- Status left ---
            # The session pill uses base foreground on a wisteria background, with two
            # spaces per side and wisteria-on-base half-circle caps.
            set -g status-left '#[fg=${wisteria},bg=${base}]#[fg=${base},bg=${wisteria}]  #S  #[fg=${wisteria},bg=${base}] '

            # --- Status right ---
            # The YubiKey touch chip precedes the honey-coloured prefix; modules keep a
            # trailing separator.
            set -g status-right '#(${lib.getExe yubikeyTouch})#{?client_prefix,#[fg=${honey}] PREFIX #[default] ,}'

            # --- Inactive window ---
            # Two spaces sit on each side without caps. A hollow circle separates #I from
            # the name, with a dash for the last-selected window. Its width matches the
            # active format, so switching does not shift adjacent windows.
            # Background follows bell > activity > base; base foreground is muted.
            # Decorations layer marked underline, last-window dash, jade silence name,
            # and ember zoom Z. Separators inherit foreground for bell/activity states.
            set -g window-status-format '#[bg=${inactiveBg}]#[fg=${inactiveFg}]  #{?window_marked_flag,#[fg=${honey}#,underscore]#I#[fg=${inactiveFg}#,nounderscore],#I} #{?window_last_flag,-,○} #{?window_silence_flag,#[fg=${jade}]${name}#[fg=${inactiveFg}],${name}}#{?window_zoomed_flag,#[fg=${ember}]Z#[fg=${inactiveFg}],}  '

            # --- Active window ---
            # Overlay background and text foreground sit inside rounded caps. The filled
            # circle inherits activeFg for bell/activity states. One inner space makes
            # the total width match the uncapped inactive format.
            set -g window-status-current-format '#[fg=${activeBg},bg=${base}]#[bg=${activeBg}]#[fg=${activeFg}] #{?window_marked_flag,#[fg=${honey}#,underscore]#I#[fg=${activeFg}#,nounderscore],#I} ● #{?window_silence_flag,#[fg=${jade}]${name}#[fg=${activeFg}],${name}}#{?window_zoomed_flag,#[fg=${ember}]Z#[fg=${activeFg}],} #[fg=${activeBg},bg=${base}]'

            # --- Window separator ---
            # One inner space per window already provides a two-space visual gap.
            set -g window-status-separator ''''''

            # --- Pane borders ---
            set -g pane-border-style 'fg=${overlay}'
            set -g pane-active-border-style 'fg=${wisteria}'

            # --- Messages ---
            set -g message-style 'fg=${text},bg=${base}'
            set -g message-command-style 'fg=${text},bg=${base}'

            # --- Clipboard ---
            # OSC 52 writes the host clipboard directly over SSH without depending on
            # xclip, wl-copy, or clip.exe.
            set -g set-clipboard on
            set -as terminal-features ',xterm*:clipboard'
        '';
    };
}
