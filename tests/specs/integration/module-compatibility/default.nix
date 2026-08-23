{
    nixpkgs,
    home-manager,
    system,
    pkgsConfig ? { },
    publicHomeModules,
    nixosModulePaths,
}:
let
    pkgs = import nixpkgs ({ inherit system; } // pkgsConfig);
    inherit (pkgs) lib;
    username = "module-compatibility-check";
    fixture = {
        home = {
            inherit username;
            homeDirectory = "/home/${username}";
            stateVersion = "25.11";
        };
    };
    mkHome =
        modules: extraSpecialArgs:
        home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            # Nix's module loader requests named arguments even when their
            # function signatures have defaults.
            extraSpecialArgs = {
                hostConfig = {
                    isWsl = false;
                    users = { };
                };
                osConfig = { };
            }
            // extraSpecialArgs;
            modules = [ fixture ] ++ modules;
        };
    require = label: condition: if condition then true else throw "module compatibility: ${label}";
    # Discard contexts only after forcing derivation paths: this is evaluation
    # coverage, not a request to build every exported tool or desktop font.
    homeSummary = configuration: {
        activation = builtins.unsafeDiscardStringContext configuration.activationPackage.drvPath;
        packages = map (
            p: builtins.unsafeDiscardStringContext p.drvPath
        ) configuration.config.home.packages;
        assertions = map (a: a.assertion) configuration.config.assertions;
    };
    zshDependencies = {
        programs = {
            fzf.enable = true;
            git.enable = true;
            tmux.enable = true;
        };
    };
    standaloneHomes = lib.mapAttrs (
        name: module: homeSummary (mkHome ([ module ] ++ lib.optional (name == "zsh") zshDependencies) { })
    ) publicHomeModules;
    zshMissingDependencies = lib.genAttrs [ "fzf" "git" "tmux" ] (
        name:
        require "zsh must reject missing ${name}" (
            !(builtins.tryEval
                (mkHome [
                    publicHomeModules.zsh
                    zshDependencies
                    { programs.${name}.enable = lib.mkForce false; }
                ] { }).activationPackage.drvPath
            ).success
        )
    );
    azureDefault = mkHome [ publicHomeModules.azure-artifacts-credprovider ] { };
    azureEnabled = mkHome [
        publicHomeModules.azure-artifacts-credprovider
        { programs.azure-artifacts-credprovider.enable = true; }
    ] { };
    azureOverride = mkHome [
        publicHomeModules.azure-artifacts-credprovider
        {
            programs.azure-artifacts-credprovider = {
                enable = true;
                package = pkgs.hello;
            };
        }
    ] { };
    graphifyDefault = mkHome [ publicHomeModules.graphify ] { };
    graphifyEnabled = mkHome [
        publicHomeModules.graphify
        { programs.graphify.enable = true; }
    ] { };
    customGraphify = pkgs.graphify.overridePythonAttrs (old: {
        dependencies = old.dependencies ++ old.optional-dependencies.openai;
    });
    graphifyOverride = mkHome [
        publicHomeModules.graphify
        {
            programs.graphify = {
                enable = true;
                package = customGraphify;
            };
        }
    ] { };
    graphifyCli =
        configuration: lib.filter (p: (p.pname or "") == "graphify-cli") configuration.config.home.packages;
    optionalChecks = {
        azureDisabled = require "Azure must be opt-in" (
            !azureDefault.config.programs.azure-artifacts-credprovider.enable
            && !(azureDefault.config.home.sessionVariables ? NUGET_PLUGIN_PATHS)
            && !(lib.elem pkgs.azure-artifacts-credprovider azureDefault.config.home.packages)
        );
        azureEnabled = require "Azure enabled/default package and plugin environment" (
            lib.elem pkgs.azure-artifacts-credprovider azureEnabled.config.home.packages
            &&
                azureEnabled.config.home.sessionVariables.NUGET_PLUGIN_PATHS
                == "${pkgs.azure-artifacts-credprovider}/lib/azure-artifacts-credprovider/CredentialProvider.Microsoft.dll"
            &&
                azureEnabled.config.home.sessionVariables.ARTIFACTS_CREDENTIALPROVIDER_MSAL_ALLOW_BROKER == "false"
        );
        azureOverride = require "Azure package override must reach package list and environment" (
            lib.elem pkgs.hello azureOverride.config.home.packages
            && lib.hasPrefix "${pkgs.hello}/" azureOverride.config.home.sessionVariables.NUGET_PLUGIN_PATHS
        );
        graphifyDisabled = require "Graphify must be opt-in" (
            !graphifyDefault.config.programs.graphify.enable && graphifyCli graphifyDefault == [ ]
        );
        graphifyEnabled = require "Graphify must install one isolated CLI, not global Python" (
            graphifyEnabled.config.programs.graphify.package == pkgs.graphify
            && builtins.length (graphifyCli graphifyEnabled) == 1
            && !(lib.elem pkgs.python3 graphifyEnabled.config.home.packages)
        );
        graphifyOverride =
            require "Graphify dependency override must reach its isolated Python environment"
                (
                    graphifyOverride.config.programs.graphify.package == customGraphify
                    &&
                        (builtins.head (graphifyCli graphifyOverride)).pythonEnvironment.drvPath
                        != (builtins.head (graphifyCli graphifyEnabled)).pythonEnvironment.drvPath
                );
    };
    optionalHomes = map homeSummary [
        azureEnabled
        azureOverride
        graphifyEnabled
        graphifyOverride
    ];
    wslHome =
        isWsl: windowsUsername:
        mkHome
            [
                publicHomeModules.git
                publicHomeModules.neovim
                publicHomeModules.starship
                publicHomeModules.yubikey-touch-notify
            ]
            {
                hostConfig = {
                    inherit isWsl;
                    users.${username} = lib.optionalAttrs (windowsUsername != null) { inherit windowsUsername; };
                };
                osConfig.programs.yubikey-touch-detector.enable = true;
            };
    linuxHome = wslHome false null;
    linuxWindowsUser = wslHome false "compatibility-check";
    wslWithoutUser = wslHome true null;
    wslWithUser = wslHome true "compatibility-check";
    nixdCount =
        configuration: builtins.length (lib.filter (p: p == pkgs.nixd) configuration.config.home.packages);
    checkWsl =
        label: configuration: isWsl: useWindowsStarship:
        let
            cfg = configuration.config;
            service = cfg.systemd.user.services.yubikey-touch-notify;
        in
        require label (
            cfg.programs.git.settings.core.autocrlf == (if isWsl then "input" else false)
            && cfg.services.dunst.enable == !isWsl
            && lib.elem pkgs.libnotify cfg.home.packages == !isWsl
            && lib.hasSuffix (if isWsl then " wsl" else " linux") (builtins.head service.Service.ExecStart)
            && service.Install.WantedBy == [ "default.target" ]
            && lib.elem "TMUX_TMPDIR=%t" service.Service.Environment
            && (cfg.home.activation ? resolveStarshipConfig) == useWindowsStarship
            && (cfg.programs.starship.settings.git_status ? windows_starship) == useWindowsStarship
        );
    wslChecks = {
        linux = checkWsl "Linux branches" linuxHome false false;
        linuxWindowsUser =
            checkWsl "Windows username alone must not enable WSL behavior" linuxWindowsUser false
                false;
        wslWithoutUser = checkWsl "WSL without Windows username" wslWithoutUser true false;
        wslWithUser = checkWsl "WSL with Windows username" wslWithUser true true;
        windowsStarship = require "Windows Starship executable must use the declared username" (
            wslWithUser.config.programs.starship.settings.git_status.windows_starship
            == "/mnt/c/Users/compatibility-check/.cargo/bin/starship.exe"
        );
        neovim = require "WSL must add its extra nixd package" (
            nixdCount wslWithoutUser == nixdCount linuxHome + 1
        );
        notifierDisabled = require "notifier must be inert without the NixOS detector" (
            !(
                (mkHome [ publicHomeModules.yubikey-touch-notify ] { }).config.systemd.user.services
                    ? yubikey-touch-notify
            )
        );
    };
    wslHomes = map homeSummary [
        linuxHome
        linuxWindowsUser
        wslWithoutUser
        wslWithUser
    ];
    standaloneSystems = lib.mapAttrs (
        name: module:
        let
            configuration = nixpkgs.lib.nixosSystem {
                inherit system;
                specialArgs = lib.optionalAttrs (name == "docker") { activeUser = username; };
                modules = [
                    module
                    {
                        nixpkgs = lib.mkMerge [
                            pkgsConfig
                            { config.allowUnfreePredicate = lib.mkDefault (p: lib.getName p == "nvidia-x11"); }
                        ];
                        system.stateVersion = "25.11";
                        boot.isContainer = true;
                        users.users.${username}.isNormalUser = true;
                    }
                    # ZFS requires a host ID even for evaluation. This is a
                    # synthetic fixture, never a pool or a deployment identity.
                    (lib.mkIf (name == "zfs") { networking.hostId = "00000000"; })
                ];
            };
        in
        {
            toplevel = builtins.unsafeDiscardStringContext configuration.config.system.build.toplevel.drvPath;
            assertions = map (a: a.assertion) configuration.config.assertions;
        }
    ) nixosModulePaths;
    manifest = builtins.toJSON {
        inherit
            standaloneHomes
            standaloneSystems
            zshMissingDependencies
            optionalChecks
            optionalHomes
            wslChecks
            wslHomes
            ;
    };
in
pkgs.runCommandLocal "module-compatibility-check" {
    manifest = pkgs.writeText "module-compatibility.json" manifest;
} (builtins.readFile ./module-compatibility.sh)
