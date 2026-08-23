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
    divider = "#3b4261";
    muted = "#565f89";
    subtle = "#a9b1d6";
    text = "#c0caf5";
    honey = "#e0af68";
    wisteria = "#bb9af7";

    # Resolved + tail-truncated display name (shortenPath for zsh windows, raw #W otherwise; cap 32 chars w/ leading ...).
    name = ''#(${lib.getExe displayName} "#W" "#{pane_current_path}")'';
in
{
    imports = [
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
            set -g status-style 'fg=${subtle},bg=${base}'
            set -g status-position top
            set -g status-justify absolute-centre
            set -g status-left-length 160
            set -g status-right-length 160
            set -g status-interval 1

            # --- Status left ---
            # W takes inactive and current formats; window_last_flag marks the previous window.
            # Grouped sessions render as group/name (e.g. nix/nix-0).
            set -g status-left ' #[fg=${wisteria},bg=${base}]  #{?session_grouped,#{session_group}/,}#S  #[fg=${divider}]• #{W:#[fg=${muted}]#[bg=${base}] #{?window_last_flag,#[underscore],}#I#{?window_marked_flag,ᴍ,}#{?window_zoomed_flag,ᴢ,}#{?window_bell_flag,!,}#{?window_activity_flag,+,}#{?window_silence_flag,~,}#{?window_last_flag,#[nounderscore],} ,#[fg=${text}]#[bg=${base}] #I#{?window_marked_flag,ᴍ,}#{?window_zoomed_flag,ᴢ,}#{?window_bell_flag,!,}#{?window_activity_flag,+,}#{?window_silence_flag,~,} } #[fg=${divider}]#[bg=${base}]•#[fg=${text}]  ${name}  '

            # --- Status right ---
            set -g status-right '#(${lib.getExe yubikeyTouch})#{?client_prefix,#[fg=${honey}] PREFIX #[default] ,} '

            # Window entries are rendered explicitly in status-left.
            set -g window-status-format ""
            set -g window-status-current-format ""

            # --- Window separator ---
            set -g window-status-separator ''''''

            # --- Panes ---
            # Equal border styles prevent junction cells from leaking active highlighting.
            set -g pane-border-style 'fg=${base},bg=${base}'
            set -g pane-active-border-style 'fg=${base},bg=${base}'
            set -g window-style 'bg=${overlay}'
            set -g window-active-style 'bg=${base}'

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
