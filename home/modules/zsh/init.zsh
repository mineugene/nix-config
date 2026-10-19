# Propagate session env to systemd user units so user services
# (mako, yubikey-touch-notify, etc.) see WAYLAND_DISPLAY/DBus.
if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment \
        WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS 2>/dev/null
fi

# Exclude directory separator from WORDCHARS
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# Bracketed paste: strip Windows CR and prevent command execution on paste
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic
zstyle :bracketed-paste-magic active-widgets '.self-insert'
_fix-paste() { PASTED=${PASTED//$'\r'/}; }
zstyle :bracketed-paste-magic paste-finish _fix-paste

# --- Autosuggestions ---
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25
export ZSH_AUTOSUGGEST_HISTORY_IGNORE='git *(--force|--force-with-lease)'

# --- Syntax highlighting ---
export ZSH_HIGHLIGHT_MAXLENGTH=512
