{
    pkgs,
    nixosSystem,
    hyprlandNvidiaModule,
}:
let
    system = nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
            hyprlandNvidiaModule
            {
                nixpkgs.config.allowUnfree = true;
                system.stateVersion = "25.11";
            }
        ];
    };
    cfg = system.config;
    etc = cfg.environment.etc;
    command = cfg.services.greetd.settings.default_session.command;
    regreet = cfg.services.displayManager.regreet;
    ewwScss = etc."greetd/eww/eww.scss".source;
    ewwYuck = etc."greetd/eww/eww.yuck".source;
    greeterSessionExecutable = etc."greetd/greeter-session".source;
    greeterSessionSource = ../nixos/modules/hyprland-nvidia/scripts/greeter-session.sh;
    wayfireConfig = etc."greetd/wayfire.ini".source;
    startGreeterSource = ../nixos/modules/hyprland-nvidia/scripts/start-greeter.sh;
in
assert cfg.programs.hyprland.withUWSM;
assert !cfg.programs.hyprland.xwayland.enable;
assert cfg.security.pam.services ? hyprlock;
assert cfg.services.greetd.enable;
assert !cfg.services.greetd.useTextGreeter;
assert regreet.enable;
assert regreet.font.size == 13;
assert regreet.cursorTheme.name == "capitaine-cursors-white";
assert regreet.cursorTheme.package == pkgs.capitaine-cursors;
assert regreet.settings.widget.clock.format == "";
assert regreet.settings.widget.clock.label_width == 0;
assert cfg.services.accounts-daemon.enable;
assert builtins.elem pkgs.eww cfg.environment.systemPackages;
assert builtins.elem pkgs.wayfire cfg.environment.systemPackages;
assert builtins.elem pkgs.wlr-randr cfg.environment.systemPackages;
assert builtins.elem regreet.package cfg.environment.systemPackages;
assert builtins.match ".*-start-greeter/bin/start-greeter" command != null;
assert etc ? "greetd/eww/eww.yuck";
assert etc ? "greetd/eww/eww.scss";
assert etc ? "greetd/greeter-session";
assert etc ? "greetd/wayfire.ini";
assert !(etc ? "greetd/hyprland.lua");
pkgs.runCommandLocal "hyprland-nvidia-check"
    {
        nativeBuildInputs = [
            pkgs.dbus
            pkgs.eww
            pkgs.wayfire
            pkgs.xvfb-run
            pkgs.shellcheck
            pkgs.dash
        ];
        inherit
            ewwScss
            ewwYuck
            greeterSessionExecutable
            greeterSessionSource
            wayfireConfig
            startGreeterSource
            ;
    }
    ''
        set -eu

        test -x "$greeterSessionExecutable"
        shellcheck --shell=sh "$greeterSessionSource" "$startGreeterSource"
        dash -n "$greeterSessionSource"
        dash -n "$startGreeterSource"
        if grep -Fq 'sh -c' "$startGreeterSource"; then
            echo 'start-greeter must not hide process lifecycle in a command string' >&2
            exit 1
        fi
        grep -Fq 'mode = mirror %s' "$startGreeterSource"
        grep -Fq 'kill -TERM "$wayfire_pid"' "$startGreeterSource"
        grep -Fq 'plugins = autostart blur place' "$wayfireConfig"
        grep -Fq 'blur_by_default = app_id is "greetd-motd"' "$wayfireConfig"
        grep -Fq 'method = kawase' "$wayfireConfig"
        grep -Fq 'autostart_wf_shell = false' "$wayfireConfig"
        grep -Fq 'greeter = /etc/greetd/greeter-session' "$wayfireConfig"

        grep -Fq '(defwindow bar' "$ewwYuck"
        grep -Fq '(defwindow motd' "$ewwYuck"
        grep -Fq '(defpoll motd_text' "$ewwYuck"
        grep -Fq ':monitor 0' "$ewwYuck"
        grep -Fq ':namespace "greetd-bar"' "$ewwYuck"
        grep -Fq ':namespace "greetd-motd"' "$ewwYuck"
        grep -Eq '/nix/store/[^/]+-fastfetch-[^/]+/bin/fastfetch --logo none --pipe' "$ewwYuck"
        grep -Fq 'font-size: 13px;' "$ewwScss"
        grep -Fq 'background-color: #16161e;' "$ewwScss"
        grep -Fq 'border: 1px solid #292e42;' "$ewwScss"
        grep -Fq 'color: #c0caf5;' "$ewwScss"
        grep -Fq 'font-family: monospace;' "$ewwScss"
        grep -Fq 'background-color: rgba(#16161e, 0.78);' "$ewwScss"

        greeter_test_bin="$TMPDIR/greeter-test-bin"
        mkdir -p "$greeter_test_bin"
        cat > "$greeter_test_bin/wlr-randr" <<'SH'
        #!/bin/sh
        if [ "$#" -eq 0 ]; then
            cat <<'EOF'
        DP-3 "Primary"
          Enabled: yes
        DP-4 "Secondary"
          Enabled: yes
        EOF
            exit 0
        fi
        printf 'wlr-randr:%s\n' "$*" >> "$GREETER_TEST_LOG"
        SH
        cat > "$greeter_test_bin/eww" <<'SH'
        #!/bin/sh
        if [ "''${XDG_CACHE_HOME:-}" != "$XDG_RUNTIME_DIR" ]; then
            echo 'greeter did not redirect Eww cache into its writable runtime directory' >&2
            exit 99
        fi
        printf 'eww:%s\n' "$*" >> "$GREETER_TEST_LOG"
        [ "''${GREETER_EWW_FAIL:-}" != "$3" ]
        SH
        cat > "$greeter_test_bin/regreet" <<'SH'
        #!/bin/sh
        printf '%s\n' regreet >> "$GREETER_TEST_LOG"
        if [ "''${GREETER_REGREET_SIGNAL_PARENT:-0}" -eq 1 ]; then
            kill -TERM "$PPID"
            exit 0
        fi
        exit "''${GREETER_REGREET_STATUS:-0}"
        SH
        cat > "$greeter_test_bin/wayfire" <<'SH'
        #!/bin/sh
        printf '%s\n' "$*" > "$GREETER_START_LOG"
        cat "$2" > "$GREETER_WAYFIRE_CONFIG_LOG"
        printf '%s\n' 0 > "$GREETER_SESSION_STATUS_FILE"
        trap 'exit 0' TERM
        while :; do sleep 1; done
        SH
        cat > "$greeter_test_bin/dbus-run-session" <<'SH'
        #!/bin/sh
        [ "$1" = -- ] && shift
        { [ "$1" = sh ] || [ "$1" = /bin/sh ]; } && shift && exec ${pkgs.dash}/bin/dash "$@"
        exec "$@"
        SH
        chmod +x "$greeter_test_bin"/*

        export PATH="$greeter_test_bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin"
        export GREETER_START_LOG="$TMPDIR/greeter-start.log"
        export GREETER_WAYFIRE_CONFIG_LOG="$TMPDIR/greeter-wayfire.ini"
        export XDG_RUNTIME_DIR="$TMPDIR/greeter-start-runtime"
        export GREETER_WAYFIRE_TEMPLATE="$wayfireConfig"
        export GREETER_DRM_DIR="$TMPDIR/drm"
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        mkdir -p "$GREETER_DRM_DIR/card0-DP-3" "$GREETER_DRM_DIR/card0-DP-4"
        printf '%s\n' connected > "$GREETER_DRM_DIR/card0-DP-3/status"
        printf '%s\n' connected > "$GREETER_DRM_DIR/card0-DP-4/status"
        "$startGreeterSource"
        test "$(cat "$GREETER_START_LOG")" = "--config $XDG_RUNTIME_DIR/wayfire.ini"
        grep -Fq '[output:DP-3]' "$GREETER_WAYFIRE_CONFIG_LOG"
        grep -Fq 'mode = auto' "$GREETER_WAYFIRE_CONFIG_LOG"
        grep -Fq '[output:DP-4]' "$GREETER_WAYFIRE_CONFIG_LOG"
        grep -Fq 'mode = mirror DP-3' "$GREETER_WAYFIRE_CONFIG_LOG"

        export HOME=/var/empty
        export XDG_RUNTIME_DIR="$TMPDIR/greeter-runtime"
        export GREETER_TEST_LOG="$TMPDIR/greeter-test.log"
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        "$greeterSessionSource"
        test "$(cat "$GREETER_TEST_LOG")" = 'eww:--config /etc/greetd/eww daemon
        eww:--config /etc/greetd/eww open bar --id bar-0 --screen 0
        eww:--config /etc/greetd/eww open motd --id motd-0 --screen 0
        eww:--config /etc/greetd/eww open bar --id bar-1 --screen 1
        eww:--config /etc/greetd/eww open motd --id motd-1 --screen 1
        regreet
        eww:--config /etc/greetd/eww kill'

        : > "$GREETER_TEST_LOG"
        GREETER_EWW_FAIL=daemon "$greeterSessionSource" 2> "$TMPDIR/eww-failure.log"
        grep -Fxq regreet "$GREETER_TEST_LOG"
        grep -Fq 'greeter: failed to start eww daemon' "$TMPDIR/eww-failure.log"

        : > "$GREETER_TEST_LOG"
        if GREETER_REGREET_STATUS=23 "$greeterSessionSource" 2> "$TMPDIR/regreet-failure.log"; then
            echo 'greeter session discarded ReGreet failure' >&2
            exit 1
        else
            status=$?
        fi
        test "$status" -eq 23
        grep -Fq 'greeter: regreet exited with status 23' "$TMPDIR/regreet-failure.log"
        grep -Fq 'eww:--config /etc/greetd/eww kill' "$GREETER_TEST_LOG"

        : > "$GREETER_TEST_LOG"
        signal_status_file="$TMPDIR/signal-status"
        if GREETER_REGREET_SIGNAL_PARENT=1 GREETER_SESSION_STATUS_FILE="$signal_status_file" \
            "$greeterSessionSource" 2> "$TMPDIR/regreet-signal.log"; then
            echo 'greeter session discarded its termination signal' >&2
            exit 1
        else
            status=$?
        fi
        test "$status" -eq 143
        test "$(cat "$signal_status_file")" -eq 143
        grep -Fq 'eww:--config /etc/greetd/eww kill' "$GREETER_TEST_LOG"

        wayfire_runtime="$TMPDIR/wayfire-runtime"
        mkdir -m 700 "$wayfire_runtime"
        XDG_RUNTIME_DIR="$wayfire_runtime" WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 \
            ${pkgs.wayfire}/bin/wayfire --config "$wayfireConfig" > "$TMPDIR/wayfire.log" 2>&1 &
        wayfire_pid=$!
        trap 'kill -TERM "$wayfire_pid" 2>/dev/null || :; wait "$wayfire_pid" 2>/dev/null || :' EXIT
        for _ in $(seq 1 100); do
            wayfire_socket=$(find "$wayfire_runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\\n' | head -n 1)
            [ -n "$wayfire_socket" ] && break
            sleep 0.1
        done
        test -n "$wayfire_socket"
        kill -TERM "$wayfire_pid"
        wait "$wayfire_pid"
        trap - EXIT
        grep -Fq 'Shutdown successful!' "$TMPDIR/wayfire.log"

        config_dir="$TMPDIR/eww"
        mkdir -p "$config_dir"
        ln -s "$ewwScss" "$config_dir/eww.scss"
        ln -s "$ewwYuck" "$config_dir/eww.yuck"

        export HOME="$TMPDIR/home"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -m 700 -p "$HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

        cat > "$TMPDIR/eww-smoke" <<'SH'
        #!/bin/sh
        set -eu

        config_dir=$1
        log=$2

        eww --config "$config_dir" daemon --no-daemonize >"$log" 2>&1 &
        daemon_pid=$!

        cleanup() {
            eww --config "$config_dir" kill >/dev/null 2>&1 || true
            kill "$daemon_pid" >/dev/null 2>&1 || true
            wait "$daemon_pid" >/dev/null 2>&1 || true
        }
        trap cleanup EXIT HUP INT TERM

        sleep 1
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            wait "$daemon_pid" || true
            cat "$log" >&2
            exit 1
        fi

        eww --config "$config_dir" ping >/dev/null
        eww --no-daemonize --config "$config_dir" open bar --id bar-0 --screen 0 >/dev/null
        eww --no-daemonize --config "$config_dir" open motd --id motd-0 --screen 0 >/dev/null
        eww --config "$config_dir" debug >/dev/null
        eww --config "$config_dir" kill >/dev/null
        wait "$daemon_pid" || true
        trap - EXIT HUP INT TERM
        SH
        chmod +x "$TMPDIR/eww-smoke"

        export PATH="${pkgs.dbus}/bin:${pkgs.eww}/bin:${pkgs.coreutils}/bin"
        if ! ${pkgs.dbus}/bin/dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
            ${pkgs.xvfb-run}/bin/xvfb-run -a "$TMPDIR/eww-smoke" "$config_dir" "$TMPDIR/eww.log"; then
            cat "$TMPDIR/eww.log" >&2
            exit 1
        fi

        touch "$out"
    ''
