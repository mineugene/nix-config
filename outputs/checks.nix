{
    self,
    nixpkgs,
    home-manager,
    preCommitHooks,
    system,
    pkgsConfig,
    publicHomeModules,
    nixosModulePaths,
    packages,
}:
let
    pkgs = nixpkgs.legacyPackages.${system};

    defaultHostConfig = {
        inherit system;
        isWsl = false;
        users = { };
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

    graphifyConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.graphify
        {
            home.username = "graphify-check";
            home.homeDirectory = "/home/graphify-check";
            home.stateVersion = "25.11";
            home.packages = [
                (pkgs.python3.withPackages (ps: [ ps.debugpy ]))
            ];
            programs.graphify = {
                enable = true;
                package = pkgs.graphify.overridePythonAttrs (old: {
                    dependencies =
                        old.dependencies
                        ++ old.optional-dependencies.openai
                        ++ old.optional-dependencies.watch
                        ++ [ pkgs.python3Packages.tree-sitter-grammars.tree-sitter-hcl ];
                });
            };
        }
    ];

    yubikeyTouchNotifyConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.yubikey-touch-notify
        {
            _module.args.osConfig.programs.yubikey-touch-detector.enable = true;
            home.username = "yubikey-touch-notify-check";
            home.homeDirectory = "/home/yubikey-touch-notify-check";
            home.stateVersion = "25.11";
        }
    ];

    hyprlandModuleConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-module-check";
            home.homeDirectory = "/home/hyprland-module-check";
            home.stateVersion = "25.11";
            # Dummy nodes: the check proves the option reaches the built
            # helper, never a real workstation sink.
            mine.desktop.audio.monitorOutputs = [
                {
                    label = "Headphones";
                    node = "alsa_output.usb-Check_Headphones-00.analog-stereo";
                }
                {
                    label = "Speakers";
                    node = "alsa_output.usb-Check_Speakers-00.analog-stereo";
                }
            ];
        }
    ];

    hyprlandHdrModuleConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-hdr-module-check";
            home.homeDirectory = "/home/hyprland-hdr-module-check";
            home.stateVersion = "25.11";
            mine.desktop.display.monitors = [
                {
                    output = "DP-1";
                    width = 3840;
                    height = 2160;
                    refreshHz = 119.88;
                    scale = 1.0;
                }
                {
                    output = "DP-2";
                    width = 1920;
                    height = 1080;
                    refreshHz = 60.00;
                    scale = 1.0;
                    cm = "hdr";
                    sdrSaturation = 1.05;
                    sdrMinLuminance = 0.005;
                    sdrMaxLuminance = 250;
                }
            ];
        }
    ];

    preCommitCheck =
        let
            prettierReport = (import ../lib/scripts.nix { inherit pkgs; }) {
                name = "prettier-report";
                src = ../lib/prettier-report.sh;
            };
            zshSyntax = pkgs.writeShellApplication {
                name = "check-zsh";
                runtimeInputs = [ pkgs.zsh ];
                text = builtins.readFile ../tests/support/check-zsh.sh;
            };
        in
        preCommitHooks.lib.${system}.run {
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
                shellcheck = {
                    enable = true;
                    excludes = [
                        "^\\.envrc$"
                        "\\.zsh$"
                    ];
                };
                zsh-syntax = {
                    enable = true;
                    name = "Zsh syntax";
                    entry = nixpkgs.lib.getExe zshSyntax;
                    files = "(\\.zsh$|^home/modules/zsh/widgets/)";
                };
                prettier = {
                    enable = true;
                    # A single invocation receives every file so the wrapper
                    # can print one consolidated, sorted failure list.
                    entry = "${prettierReport}/bin/prettier-report ${pkgs.prettier}/bin/prettier .prettierrc.json";
                    require_serial = true;
                };
            };
        };

    boundaryCheck = pkgs.runCommandLocal "public-boundary-check" {
        nativeBuildInputs = [
            pkgs.coreutils
            pkgs.gitleaks
        ];
        src = self;
    } (builtins.readFile ../tests/specs/unit/public-boundary/public-boundary.sh);

    hyprlandLuaCheck = import ../tests/specs/integration/hyprland-lua {
        inherit pkgs;
        configuredMonitor =
            hyprlandHdrModuleConfiguration.config.xdg.configFile."hypr/generated/monitor.lua".source;
        hyprlandFiles = hyprlandModuleConfiguration.config.xdg.configFile;
    };

    monitorTopologyCheck =
        let
            monitorTopologyPackage = builtins.head (
                builtins.filter (
                    package: nixpkgs.lib.getName package == "monitor-topology"
                ) hyprlandModuleConfiguration.config.home.packages
            );
        in
        import ../tests/specs/integration/monitor-topology {
            inherit pkgs;
            monitorTopology = nixpkgs.lib.getExe monitorTopologyPackage;
            monitorTopologyService = hyprlandModuleConfiguration.config.systemd.user.services.monitor-topology;
        };

    desktopThemeCheck = import ../tests/specs/integration/desktop-theme {
        inherit pkgs;
        homePackages = hyprlandModuleConfiguration.config.home.packages;
        defaultMode = hyprlandModuleConfiguration.config.mine.desktop.theme.defaultMode;
        swayncDarkTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-dark.css".source;
        swayncLightTheme =
            hyprlandModuleConfiguration.config.xdg.configFile."mineugene-desktop/theme/swaync-light.css".source;
    };

    swayncCheck = import ../tests/specs/integration/swaync {
        inherit pkgs;
        inherit (hyprlandModuleConfiguration.config.services) swaync;
        swayncConfig = hyprlandModuleConfiguration.config.xdg.configFile."swaync/config.json".source;
    };

    hypridleCheck = import ../tests/specs/unit/hypridle {
        inherit pkgs;
        hypridleConfig = hyprlandModuleConfiguration.config.xdg.configFile."hypr/hypridle.conf".source;
    };

    rofiCheck = import ../tests/specs/integration/rofi {
        inherit pkgs;
        homePackages = hyprlandModuleConfiguration.config.home.packages;
    };

    hyprlandNvidiaCheck = import ../tests/specs/integration/hyprland-nvidia {
        inherit pkgs;
        nixosSystem = nixpkgs.lib.nixosSystem;
        hyprlandNvidiaModule = nixosModulePaths.hyprland-nvidia;
    };

    composeCheck = import ../tests/specs/integration/compose {
        inherit pkgs;
        nixosSystem = nixpkgs.lib.nixosSystem;
        composeModule = nixosModulePaths.compose;
    };

    posixShellCheck = import ../tests/specs/unit/posix-shell {
        inherit pkgs;
        src = self;
    };

    runtimeBoundaryCheck = import ../tests/specs/unit/runtime-boundary {
        inherit pkgs;
        src = self;
    };

    tmuxScriptsCheck = import ../tests/specs/integration/tmux-scripts {
        inherit pkgs;
        homePackages = publicModuleConfiguration.config.home.packages;
        tmuxSessionSwitcher =
            publicModuleConfiguration.config.xdg.configFile."zsh/widgets/tmux-session-switcher".source;
    };

    gitScriptsCheck = import ../tests/specs/integration/git-scripts {
        inherit pkgs;
        homePackages = publicModuleConfiguration.config.home.packages;
    };

    graphifyCheck = import ../tests/specs/integration/graphify {
        inherit pkgs;
        homePath = graphifyConfiguration.config.home.path;
        graphify = builtins.head (
            builtins.filter (
                package: (package.pname or "") == "graphify-cli"
            ) graphifyConfiguration.config.home.packages
        );
    };

    yubikeyTouchNotifyCheck = import ../tests/specs/integration/yubikey-touch-notify {
        inherit pkgs;
        homePackages = yubikeyTouchNotifyConfiguration.config.home.packages;
        userService = yubikeyTouchNotifyConfiguration.config.systemd.user.services.yubikey-touch-notify;
    };

    yaziCheck = import ../tests/specs/integration/yazi {
        inherit pkgs;
        yazi = publicModuleConfiguration.config.programs.yazi;
        yaziTheme = publicModuleConfiguration.config.xdg.configFile."yazi/theme.toml".source;
        yaziSettings = publicModuleConfiguration.config.xdg.configFile."yazi/yazi.toml".source;
        yaziInit = publicModuleConfiguration.config.xdg.configFile."yazi/init.lua".text;
    };

    ewwCheck = import ../tests/specs/integration/eww {
        inherit pkgs;
        eww = hyprlandModuleConfiguration.config.programs.eww;
        ewwFiles = hyprlandModuleConfiguration.config.xdg.configFile;
        homePackages = hyprlandModuleConfiguration.config.home.packages;
    };
in
let
    checks = {
        boundary = boundaryCheck;
        compose = composeCheck;
        hyprland-lua = hyprlandLuaCheck;
        monitor-topology = monitorTopologyCheck;
        hyprland-nvidia = hyprlandNvidiaCheck;
        posix-shell = posixShellCheck;
        runtime-boundary = runtimeBoundaryCheck;
        tmux-scripts = tmuxScriptsCheck;
        git-scripts = gitScriptsCheck;
        graphify = graphifyCheck;
        iosevka-logging = import ../tests/specs/unit/iosevka-logging {
            pkgs = import nixpkgs ({ inherit system; } // pkgsConfig);
        };
        pi-settings = import ../tests/specs/unit/pi-settings { inherit pkgs; };
        source-helpers = import ../tests/specs/unit/source-helpers { inherit pkgs; };
        zsh-syntax = import ../tests/specs/unit/zsh-syntax {
            inherit pkgs;
            src = self;
        };
        yubikey-touch-notify = yubikeyTouchNotifyCheck;
        hypridle = hypridleCheck;
        desktop-theme = desktopThemeCheck;
        yazi = yaziCheck;
        eww = ewwCheck;
        eww-runtime = import ../tests/specs/integration/eww/runtime.nix { inherit pkgs; };
        rofi = rofiCheck;
        swaync = swayncCheck;
        home-public-modules = publicModuleConfiguration.activationPackage;
        pre-commit = preCommitCheck;
        service-lifecycle = import ../tests/specs/e2e/service-lifecycle { inherit pkgs; };
        module-compatibility = import ../tests/specs/integration/module-compatibility {
            inherit
                nixpkgs
                home-manager
                system
                pkgsConfig
                publicHomeModules
                nixosModulePaths
                ;
        };
        home-activation = import ../tests/specs/integration/home-activation {
            inherit
                nixpkgs
                home-manager
                system
                pkgsConfig
                publicHomeModules
                ;
        };
        fonts = import ../tests/specs/integration/fonts {
            inherit pkgs;
            fonts = packages;
        };
        inherit (packages)
            gitleaks
            iosevka-aile-nf
            iosevka-etoile-nf
            iosevka-nf
            iosevka-term-nf
            yubikey-touch-detector
            ;
    };
    fontChecks = [
        "fonts"
        "iosevka-aile-nf"
        "iosevka-etoile-nf"
        "iosevka-nf"
        "iosevka-term-nf"
    ];
in
checks
// {
    # Font packages rebuild Iosevka from source; keep them out of the quick gate.
    fast = pkgs.linkFarm "fast-checks" (builtins.removeAttrs checks fontChecks);
}
