{
    programs.tmux.extraConfig = ''
        # --- Windows ---
        bind c new-window -c "#{pane_current_path}"
        unbind C-n
        unbind C-p
        bind n next-window
        bind p previous-window
        bind '<' swap-window -t -1
        bind '>' swap-window -t +1
        bind Tab last-window

        bind 1 select-window -t:1
        bind 2 select-window -t:2
        bind 3 select-window -t:3
        bind 4 select-window -t:4
        bind 5 select-window -t:5
        bind 6 select-window -t:6
        bind 7 select-window -t:7
        bind 8 select-window -t:8
        bind 9 select-window -t:9
        bind 0 select-window -t:10

        # --- Panes ---
        unbind '"'
        unbind '%'
        bind s split-window -v -c "#{pane_current_path}"
        bind v split-window -h -c "#{pane_current_path}"
        bind S split-window -fv -c "#{pane_current_path}"
        bind V split-window -fh -c "#{pane_current_path}"

        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5

        bind o select-pane -t :.+
        bind O select-pane -t :.-
        bind -r '{' swap-pane -U
        bind -r '}' swap-pane -D
        bind z resize-pane -Z

        # --- Copy mode (vim-consistent) ---
        bind C-v copy-mode
        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi V send-keys -X select-line
        bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

        bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
        bind -T copy-mode-vi Y send-keys -X copy-selection-and-cancel \; paste-buffer
        bind -T copy-mode-vi Escape send-keys -X cancel

        bind '/' copy-mode \; send-keys "/"
        bind '?' copy-mode \; send-keys "?"
        bind C-y paste-buffer -s ""
        bind C-Y choose-buffer "paste-buffer -b '%%' -s '''"

        # --- Session switcher ---
        bind f display-popup -E -w 80% -h 60% "zsh $HOME/.config/zsh/widgets/tmux-session-switcher"
        bind a run-shell -b 'pi-session-tracker focus-next "#{pane_id}" "#{client_name}"'

        # --- Reload ---
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"
    '';
}
