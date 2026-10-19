{
    self,
    nixpkgs,
    home-manager,
    publicLib,
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
            _module.args.osConfig.services.power-profiles-daemon.enable = true;
            home.username = "hyprland-module-check";
            home.homeDirectory = "/home/hyprland-module-check";
            home.stateVersion = "25.11";
        }
    ];

    hyprlandExtensionConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-extension-check";
            home.homeDirectory = "/home/hyprland-extension-check";
            home.stateVersion = "25.11";
            mine.desktop.audio.extension = {
                qml = ../tests/specs/integration/quickshell/audio-extension;
                packages = [ pkgs.jq ];
            };
        }
    ];

    hyprlandActivationConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "hyprland-activation-check";
            home.homeDirectory = "/home/hyprland-activation-check";
            home.stateVersion = "25.11";
            mine.desktop.hyprland.reloadOnActivation = true;
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

    gettyLaunchConfiguration = mkHomeConfiguration defaultHostConfig [
        publicHomeModules.hyprland
        {
            home.username = "getty-launch-check";
            home.homeDirectory = "/home/getty-launch-check";
            home.stateVersion = "25.11";
            programs.zsh.enable = true;
            mine.desktop.hyprland.launchFromTty = true;
        }
    ];

    preCommitCheck =
        let
            zshSyntax = pkgs.writeShellApplication {
                name = "check-zsh";
                runtimeInputs = [ pkgs.zsh ];
                text = builtins.readFile ../tests/support/check-zsh.sh;
            };
        in
        publicLib.mkPreCommit {
            inherit pkgs system;
            src = self;
            extraHooks = {
                stylua = {
                    enable = true;
                    name = "stylua";
                    package = pkgs.stylua;
                    entry = "${pkgs.stylua}/bin/stylua --check";
                    files = "\\.lua$";
                };
                ruff = {
                    enable = true;
                    name = "ruff";
                    package = pkgs.ruff;
                    entry = "${pkgs.ruff}/bin/ruff check";
                    files = "\\.py$";
                };
                ruff-format = {
                    enable = true;
                    name = "ruff format";
                    package = pkgs.ruff;
                    entry = "${pkgs.ruff}/bin/ruff format --check";
                    files = "\\.py$";
                };
                zsh-syntax = {
                    enable = true;
                    name = "zsh syntax";
                    entry = nixpkgs.lib.getExe zshSyntax;
                    files = "(\\.zsh$|^home/modules/zsh/widgets/)";
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
    };

    hypridleCheck = import ../tests/specs/unit/hypridle {
        inherit pkgs;
        hypridleConfig = hyprlandModuleConfiguration.config.xdg.configFile."hypr/hypridle.conf".source;
    };

    rofiCheck = import ../tests/specs/integration/rofi {
        inherit pkgs;
        homePackages = hyprlandModuleConfiguration.config.home.packages;
    };

    hyprlandActivationCheck = import ../tests/specs/integration/hyprland-activation {
        inherit pkgs;
        activation = hyprlandActivationConfiguration.config.home.activation;
        defaultActivation = hyprlandModuleConfiguration.config.home.activation;
        reloadScript = ../home/modules/hyprland/scripts/reload-hyprland.sh;
    };

    gettyAutologinCheck = import ../tests/specs/integration/getty-autologin {
        inherit pkgs;
        nixosSystem = nixpkgs.lib.nixosSystem;
        gettyAutologinModule = nixosModulePaths.getty-autologin;
        loginGuard = gettyLaunchConfiguration.config.programs.zsh.loginExtra;
    };

    posixShellCheck = publicLib.mkPosixShellCheck {
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

    quickshellCheck = import ../tests/specs/integration/quickshell {
        inherit pkgs;
        qmlLint = publicLib.qmlLint;
        shellConfig = hyprlandModuleConfiguration.config.xdg.configFile."quickshell/desktop".source;
        extensionShellConfig =
            hyprlandExtensionConfiguration.config.xdg.configFile."quickshell/desktop".source;
        extensionShellService = hyprlandExtensionConfiguration.config.systemd.user.services.quickshell;
        shellService = hyprlandModuleConfiguration.config.systemd.user.services.quickshell;
        lockService = hyprlandModuleConfiguration.config.systemd.user.services.shell-lock;
        lockEnable =
            hyprlandModuleConfiguration.config.xdg.dataFile."systemd/user/graphical-session.target.wants/shell-lock.service".source;
        pamModule = ../nixos/modules/hyprland-nvidia/default.nix;
    };
in
let
    checks = {
        boundary = boundaryCheck;
        hyprland-lua = hyprlandLuaCheck;
        hyprland-activation = hyprlandActivationCheck;
        monitor-topology = monitorTopologyCheck;
        getty-autologin = gettyAutologinCheck;
        posix-shell = posixShellCheck;
        runtime-boundary = runtimeBoundaryCheck;
        tmux-scripts = tmuxScriptsCheck;
        git-scripts = gitScriptsCheck;
        graphify = graphifyCheck;
        pi-settings = import ../tests/specs/unit/pi-settings { inherit pkgs; };
        source-helpers = import ../tests/specs/unit/source-helpers { inherit pkgs; };
        yubikey-touch-notify = yubikeyTouchNotifyCheck;
        hypridle = hypridleCheck;
        desktop-theme = desktopThemeCheck;
        yazi = yaziCheck;
        quickshell = quickshellCheck;
        shell-scripts = import ../tests/specs/integration/shell-scripts { inherit pkgs; };
        rofi = rofiCheck;
        home-public-modules = publicModuleConfiguration.activationPackage;
        pre-commit = preCommitCheck;
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
            inherit (packages) iosevka-ss04;
        };
        inherit (packages)
            gitleaks
            iosevka-ss04
            yubikey-touch-detector
            ;
    };
    fontChecks = [
        "fonts"
        "iosevka-ss04"
    ];
in
checks
// {
    # Font checks fetch prebuilt Iosevka releases; keep them out of the quick gate.
    fast = pkgs.linkFarm "fast-checks" (builtins.removeAttrs checks fontChecks);
}
