{
    config,
    lib,
    hostConfig ? {
        isWsl = false;
        users = { };
    },
    ...
}:
let
    userConfig = hostConfig.users.${config.home.username} or { };
    windowsUsername = userConfig.windowsUsername or null;
    useWindowsStarship = hostConfig.isWsl && windowsUsername != null;
    windowsStarshipPath = "/mnt/c/Users/${windowsUsername}/.cargo/bin/starship.exe";
in
{
    # Replace the Home Manager symlink with a real file so Windows can read it
    # via \\wsl.localhost\ when starship delegates git_status to the Windows binary.
    home.activation.resolveStarshipConfig = lib.mkIf useWindowsStarship (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            configPath="${config.xdg.configHome}/starship/config.toml"
            cp -L "$configPath" "$configPath.tmp" && mv -f "$configPath.tmp" "$configPath"
        ''
    );

    programs.starship = {
        enable = true;
        enableZshIntegration = true;
        configPath = "${config.xdg.configHome}/starship/config.toml";

        settings = {
            add_newline = false;
            command_timeout = 1500;
            scan_timeout = 50;
            continuation_prompt = "[ 🭱  ](fg:muted)";

            format = lib.concatStrings [
                "[](fg:overlay)"
                "$direnv"
                "$nix_shell"
                "$username"
                "$hostname"
                "$directory"
                "$git_branch"
                "$git_state"
                "$git_status"
                "[](fg:overlay)"
                "$line_break"
                "$character"
            ];

            right_format = lib.concatStrings [
                "[](fg:overlay)"
                "$custom"
                "$status"
                "$c"
                "$dotnet"
                "$golang"
                "$lua"
                "$nodejs"
                "$python"
                "$rust"
                "$cmd_duration"
                "$time"
                "[](fg:overlay)"
            ];

            palette = "tokyo-night";

            palettes.tokyo-night = {
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
            };

            line_break.disabled = false;

            custom.yubikey_touch = {
                description = "Pending YubiKey touch";
                command = ''cat "''${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch/active"'';
                when = ''test -s "''${XDG_RUNTIME_DIR:-/tmp}/yubikey-touch/active"'';
                format = "[ YK $output ]($style) ";
                style = "bg:overlay fg:sakura";
                shell = [
                    "sh"
                    "-c"
                ];
            };

            direnv = {
                disabled = false;
                format = "[ $loaded( $allowed) ](bg:overlay fg:wisteria)";
                allowed_msg = "";
                not_allowed_msg = "";
                denied_msg = "✖";
                loaded_msg = "";
                unloaded_msg = "";
                style = "bg:overlay fg:wisteria";
                symbol = "";
            };

            nix_shell = {
                style = "bg:overlay fg:wisteria";
                format = "[ $symbol$state( \\($name\\)) ](bg:overlay fg:wisteria)";
                pure_msg = "󱩰";
                impure_msg = "󰼩";
                unknown_msg = "󱓣";
                symbol = "";
            };

            username = {
                style_user = "bg:overlay fg:wisteria";
                style_root = "bg:overlay fg:wisteria";
                format = "[ $user ](bg:overlay fg:wisteria)";
                show_always = false;
            };

            hostname = {
                format = "[ @$hostname $ssh_symbol ](bg:overlay fg:wisteria)";
                ssh_symbol = "";
                ssh_only = true;
            };

            directory = {
                format = "[ $path ](bg:overlay fg:text)";
                home_symbol = "~";
                read_only = " ";
                read_only_style = "fg:sakura";
                style = "bg:overlay fg:text";
                truncate_to_repo = true;
                truncation_length = 3;
                truncation_symbol = " /";
                use_os_path_sep = false;
            };

            git_branch = {
                symbol = " ";
                style = "bg:overlay fg:glacier";
                format = "[ $symbol$branch ](bg:overlay fg:glacier)";
            };

            git_status = {
                style = "bg:overlay fg:glacier";
                format = "[($all_status$ahead_behind )](bg:overlay fg:glacier)";
                conflicted = "✖";
                ahead = "▲";
                behind = "▼";
                diverged = "∇";
                untracked = "?";
                stashed = "§";
                modified = "±";
                staged = "#";
                renamed = "ẟ";
                deleted = "-";
            }
            // lib.optionalAttrs useWindowsStarship {
                windows_starship = windowsStarshipPath;
            };

            git_state = {
                style = "bg:overlay fg:glacier";
                format = "[ $state(\\($progress_current/$progress_total\\)) ](bg:overlay fg:glacier)";
                rebase = "rebase";
                merge = "merge";
                revert = "revert";
                cherry_pick = "cherry-pick";
                bisect = "bisect";
                am = "am";
                am_or_rebase = "am/rebase";
            };

            c = {
                symbol = "c";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol(-$version(-$name)) ](bg:overlay fg:text)";
                disabled = false;
            };

            dotnet = {
                symbol = ".net";
                version_format = "(\${raw})";
                style = "bg:overlay fg:text";
                detect_extensions = [
                    "sln"
                    "csproj"
                    "fsproj"
                    "xproj"
                ];
                detect_files = [
                    "global.json"
                    "project.json"
                    "Directory.Build.props"
                    "Directory.Build.targets"
                    "Packages.props"
                ];
                format = "[ $symbol(-$version(-$tfm)) ](bg:overlay fg:text)";
                heuristic = true;
                disabled = false;
            };

            golang = {
                symbol = "go";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol(-$version) ](bg:overlay fg:text)";
                disabled = false;
            };

            lua = {
                symbol = "lua";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol(-$version) ](bg:overlay fg:text)";
                disabled = false;
            };

            nodejs = {
                symbol = "js";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol(-$version) ](bg:overlay fg:text)";
                disabled = false;
            };

            python = {
                symbol = "py";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol$pyenv_prefix(-$version)( \\($virtualenv\\)) ](bg:overlay fg:text)";
                disabled = false;
            };

            rust = {
                symbol = "rs";
                version_format = "\${raw}";
                style = "bg:overlay fg:text";
                format = "[ $symbol(-$version) ](bg:overlay fg:text)";
                disabled = false;
            };

            cmd_duration = {
                min_time = 0;
                show_milliseconds = false;
                style = "bg:overlay fg:muted";
                format = "[ 󱎫 $duration ](bg:overlay fg:muted)";
            };

            time = {
                time_format = "%R";
                style = "bg:overlay fg:muted";
                format = "[ 󰥔 $time ](bg:overlay fg:muted)";
                disabled = false;
            };

            status = {
                style = "bg:overlay fg:honey";
                format = "[ $symbol$common_meaning$signal_name$maybe_int ](bg:overlay fg:honey)";
                symbol = "󰣑 ";
                disabled = false;
            };

            character = {
                success_symbol = "[%](bold fg:glacier)";
                error_symbol = "[%](bold fg:sakura)";
                vimcmd_symbol = "[:](bold fg:glacier)";
                format = " [$symbol]($style) ";
            };
        };
    };
}
