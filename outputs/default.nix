inputs@{
    self,
    nixpkgs,
    home-manager,
    ...
}:
let
    system = "x86_64-linux";

    publicOverlay = nixpkgs.lib.composeManyExtensions [
        (import ../overlays)
        inputs.rust-overlay.overlays.default
    ];

    modulePaths = {
        azure-artifacts-credprovider = ../home/modules/azure-artifacts-credprovider;
        bat = ../home/modules/bat;
        copilot = ../home/modules/copilot;
        docker = ../home/modules/docker;
        dotnet = ../home/modules/dotnet;
        fd = ../home/modules/fd;
        fzf = ../home/modules/fzf;
        git = ../home/modules/git;
        git-ignore = ../home/modules/git-ignore;
        go = ../home/modules/go;
        gpg = ../home/modules/gpg;
        hyprland = ../home/modules/hyprland;
        jj = ../home/modules/jj;
        less = ../home/modules/less;
        lsd = ../home/modules/lsd;
        neovim = ../home/modules/neovim;
        nixfmt = ../home/modules/nixfmt;
        nodejs = ../home/modules/nodejs;
        python = ../home/modules/python;
        rsync = ../home/modules/rsync;
        rtk = ../home/modules/rtk;
        rust = ../home/modules/rust;
        ssh = ../home/modules/ssh;
        starship = ../home/modules/starship;
        tmux = ../home/modules/tmux;
        vim = ../home/modules/vim;
        yubikey-touch-notify = ../home/modules/yubikey-touch-notify;
        zoxide = ../home/modules/zoxide;
    };

    nixosModulePaths = {
        base = ../nixos/modules/base;
        compose = ../nixos/modules/compose;
        docker = ../nixos/modules/docker;
        fido2 = ../nixos/modules/fido2;
        hyprland-nvidia = ../nixos/modules/hyprland-nvidia;
        nix-gc = ../nixos/modules/nix-gc;
        openxlr = {
            imports = [
                inputs.openxlr.nixosModules.default
                ../nixos/modules/openxlr
            ];
        };
        openrgb = ../nixos/modules/openrgb;
        yubikey = ../nixos/modules/yubikey;
        zfs = ../nixos/modules/zfs;
    };

    publicHomeModules = modulePaths // {
        pi =
            {
                config,
                lib,
                pkgs,
                ...
            }:
            import ../home/modules/pi {
                inherit config lib pkgs;
                piDevConfig = inputs.pi-dev-config;
            };
        zsh =
            {
                config,
                lib,
                pkgs,
                ...
            }:
            import ../home/modules/zsh {
                inherit config lib pkgs;
                zshGitEscapeMagicSrc = inputs.zsh-git-escape-magic;
                zshGitIgnoreSrc = inputs.zsh-git-ignore;
            };

        shared =
            {
                config,
                lib,
                pkgs,
                ...
            }:
            import ../home/users/shared/main.nix {
                inherit config lib pkgs;
                publicModules = publicHomeModules;
            };
        default = publicHomeModules.shared;
    };

    defaultHostConfig = {
        name = "generic-linux";
        system = "x86_64-linux";
        kind = "other";
        isWsl = false;
        users = { };
        modules = [ ];
        nixpkgs = null;
        homeManager = null;
    };

    pkgsConfig = {
        overlays = [ publicOverlay ];
    };

    mkHomeConfiguration =
        hostConfig: modules:
        home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs ({ inherit (hostConfig) system; } // pkgsConfig);
            inherit modules;
            extraSpecialArgs = { inherit hostConfig; };
        };

    publicModuleConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.shared
        publicHomeModules.azure-artifacts-credprovider
        publicHomeModules.copilot
        publicHomeModules.docker
        publicHomeModules.dotnet
        publicHomeModules.go
        publicHomeModules.jj
        publicHomeModules.nodejs
        publicHomeModules.pi
        publicHomeModules.python
        publicHomeModules.rtk
        publicHomeModules.rust
        publicHomeModules.yubikey-touch-notify
        {
            home.username = "public-module-check";
            home.homeDirectory = "/home/public-module-check";
            programs.azure-artifacts-credprovider.enable = true;
        }
    ];

    hyprlandModuleConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-module-check";
            home.homeDirectory = "/home/hyprland-module-check";
            home.stateVersion = "25.11";
        }
    ];

    hyprlandHdrModuleConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-hdr-module-check";
            home.homeDirectory = "/home/hyprland-hdr-module-check";
            home.stateVersion = "25.11";
            mine.desktop.display.hdrMonitor = {
                output = "DP-1";
                width = 3840;
                height = 2160;
                refreshHz = 119.88;
                scale = 1.0;
            };
        }
    ];

    hyprlandLegacyGtk4ThemeConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        (
            { config, ... }:
            {
                home.username = "hyprland-legacy-gtk4-theme-check";
                home.homeDirectory = "/home/hyprland-legacy-gtk4-theme-check";
                home.stateVersion = "25.11";
                gtk.gtk4.theme = config.gtk.theme;
            }
        )
    ];

    packages.${system} =
        let
            pkgs = import nixpkgs ({ inherit system; } // pkgsConfig);
        in
        {
            gitleaks = pkgs.gitleaks;
            iosevka-aile-nf = pkgs.iosevka-aile-nf;
            iosevka-etoile-nf = pkgs.iosevka-etoile-nf;
            iosevka-nf = pkgs.iosevka-nf;
            iosevka-term-nf = pkgs.iosevka-term-nf;
            yubikey-touch-detector = pkgs.yubikey-touch-detector;
        };

    preCommitCheck =
        let
            pkgs = nixpkgs.legacyPackages.${system};
        in
        inputs.pre-commit-hooks.lib.${system}.run {
            src = self;
            hooks = {
                convco.enable = true;
                editorconfig-checker = {
                    enable = true;
                    files = "^justfile$";
                };
                nixfmt = {
                    enable = true;
                    entry = "${pkgs.nixfmt}/bin/nixfmt --indent=4 --check";
                };
                prettier = {
                    enable = true;
                    settings = {
                        check = true;
                        configPath = ".prettierrc.json";
                        list-different = false;
                        write = false;
                    };
                };
            };
        };

    boundaryCheck =
        let
            pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.runCommandLocal "public-boundary-check"
            {
                nativeBuildInputs = [ pkgs.gitleaks ];
                src = self;
            }
            ''
                cp -R "$src" source
                cd source

                gitleaks detect --no-banner --no-git --redact --source .

                for private_path in hosts infra secrets .sops.yaml; do
                    if [ -e "$private_path" ]; then
                        echo "private repository path found: $private_path" >&2
                        exit 1
                    fi
                done

                touch "$out"
            '';

    hyprlandLuaCheck = import ../tests/hyprland-lua.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        configuredMonitor =
            hyprlandHdrModuleConfiguration.config.xdg.configFile."hypr/generated/monitor.lua".source;
        hyprland = hyprlandModuleConfiguration.config.wayland.windowManager.hyprland;
        hyprlandFiles = hyprlandModuleConfiguration.config.xdg.configFile;
        hyprlock = hyprlandModuleConfiguration.config.programs.hyprlock;
        hyprlockFile = hyprlandModuleConfiguration.config.xdg.configFile."hypr/hyprlock.conf".source;
        pointerCursor = hyprlandModuleConfiguration.config.home.pointerCursor;
    };

    monitorTopologyCheck =
        let
            monitorTopologyPackage = builtins.head (
                builtins.filter (
                    package: nixpkgs.lib.getName package == "monitor-topology"
                ) hyprlandModuleConfiguration.config.home.packages
            );
        in
        import ../tests/monitor-topology.nix {
            pkgs = nixpkgs.legacyPackages.${system};
            monitorTopology = nixpkgs.lib.getExe monitorTopologyPackage;
            monitorTopologyService = hyprlandModuleConfiguration.config.systemd.user.services.monitor-topology;
        };

    themeCheck = import ../tests/theme.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        ghostty = hyprlandModuleConfiguration.config.programs.ghostty;
        theme = hyprlandModuleConfiguration.config.mine.desktop.theme;
        themeFiles = hyprlandModuleConfiguration.config.xdg.configFile;
    };

    desktopThemeCheck = import ../tests/desktop-theme.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        homePackages = hyprlandModuleConfiguration.config.home.packages;
        defaultMode = hyprlandModuleConfiguration.config.mine.desktop.theme.defaultMode;
        swayncDarkTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-dark.css".source;
        swayncLightTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-light.css".source;
    };

    swayncCheck = import ../tests/swaync.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (hyprlandModuleConfiguration.config.services)
            dunst
            swaync
            ;
        darkTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-dark.css".source;
        lightTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-light.css".source;
        swayncConfig = hyprlandModuleConfiguration.config.xdg.configFile."swaync/config.json".source;
        swayncService = hyprlandModuleConfiguration.config.systemd.user.services.swaync;
        swayncStyle = hyprlandModuleConfiguration.config.xdg.configFile."swaync/style.css".source;
    };

    hyprlockPamCheck = import ../tests/hyprlock-pam.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        nixosSystem = nixpkgs.lib.nixosSystem;
    };

    hypridleCheck = import ../tests/hypridle.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        hypridle = hyprlandModuleConfiguration.config.services.hypridle;
        hypridleConfig = hyprlandModuleConfiguration.config.xdg.configFile."hypr/hypridle.conf".source;
        hypridleService = hyprlandModuleConfiguration.config.systemd.user.services.hypridle;
        hyprlandRoot = hyprlandModuleConfiguration.config.xdg.configFile."hypr/hyprland.lua".source;
    };

    gtk4ThemeCompatibilityCheck = import ../tests/gtk4-theme.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        defaultGtk4Theme = hyprlandModuleConfiguration.config.gtk.gtk4.theme;
        gtk4Theme = hyprlandLegacyGtk4ThemeConfiguration.config.gtk.gtk4.theme;
    };

    rofiCheck = import ../tests/rofi.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        homePackages = hyprlandModuleConfiguration.config.home.packages;
        rofiFiles = hyprlandModuleConfiguration.config.xdg.configFile;
    };

    hyprlandNvidiaCheck = import ../tests/hyprland-nvidia.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        nixosSystem = nixpkgs.lib.nixosSystem;
        hyprlandNvidiaModule = nixosModulePaths.hyprland-nvidia;
    };

    composeCheck = import ../tests/compose.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        nixosSystem = nixpkgs.lib.nixosSystem;
        composeModule = nixosModulePaths.compose;
    };

    posixShellCheck = import ../tests/posix-shell.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        src = self;
    };

    runtimeBoundaryCheck = import ../tests/runtime-boundary.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        src = self;
    };

    tmuxScriptsCheck = import ../tests/tmux-scripts.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        homePackages = publicModuleConfiguration.config.home.packages;
    };

    openxlrCheck = import ../tests/openxlr.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        nixosSystem = nixpkgs.lib.nixosSystem;
        openxlrModule = nixosModulePaths.openxlr;
    };

    ewwCheck = import ../tests/eww.nix {
        desktopReadme = ../home/modules/hyprland/README.md;
        pkgs = nixpkgs.legacyPackages.${system};
        eww = hyprlandModuleConfiguration.config.programs.eww;
        ewwFiles = hyprlandModuleConfiguration.config.xdg.configFile;
        ewwService = hyprlandModuleConfiguration.config.systemd.user.services.eww;
        homePackages = hyprlandModuleConfiguration.config.home.packages;
        themeTokens =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/tokens.scss".source;
        waybar = hyprlandModuleConfiguration.config.programs.waybar;
    };

    devShells.${system}.default =
        let
            pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
            name = "nix-config";
            packages = [
                pkgs.dash
                pkgs.just
                pkgs.nixd
                pkgs.shellcheck
            ]
            ++ preCommitCheck.enabledPackages;
            inherit (preCommitCheck) shellHook;
        };

    checks.${system} = {
        boundary = boundaryCheck;
        compose = composeCheck;
        hyprland-lua = hyprlandLuaCheck;
        monitor-topology = monitorTopologyCheck;
        hyprland-nvidia = hyprlandNvidiaCheck;
        posix-shell = posixShellCheck;
        runtime-boundary = runtimeBoundaryCheck;
        tmux-scripts = tmuxScriptsCheck;
        hyprlock-pam = hyprlockPamCheck;
        openxlr = openxlrCheck;
        hypridle = hypridleCheck;
        desktop-theme = desktopThemeCheck;
        eww = ewwCheck;
        rofi = rofiCheck;
        swaync = swayncCheck;
        gtk4-theme-compatibility = gtk4ThemeCompatibilityCheck;
        theme = themeCheck;
        home-public-modules = publicModuleConfiguration.activationPackage;
        pre-commit = preCommitCheck;
        inherit (packages.${system})
            gitleaks
            iosevka-aile-nf
            iosevka-etoile-nf
            iosevka-nf
            iosevka-term-nf
            yubikey-touch-detector
            ;
    };
in
{
    inherit
        checks
        devShells
        packages
        ;

    homeModules = publicHomeModules;
    nixosModules = nixosModulePaths;
    overlays.default = publicOverlay;
}
