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
        bottom = ../home/modules/bottom;
        copilot = ../home/modules/copilot;
        docker = ../home/modules/docker;
        dotnet = ../home/modules/dotnet;
        fd = ../home/modules/fd;
        fzf = ../home/modules/fzf;
        git = ../home/modules/git;
        git-ignore = ../home/modules/git-ignore;
        go = ../home/modules/go;
        gpg = ../home/modules/gpg;
        graphify = ../home/modules/graphify;
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
        yazi = ../home/modules/yazi;
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

    pkgsConfig = {
        overlays = [ publicOverlay ];
    };

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

    checks.${system} = import ./checks.nix {
        inherit
            self
            nixpkgs
            home-manager
            system
            pkgsConfig
            publicHomeModules
            nixosModulePaths
            ;
        preCommitHooks = inputs.pre-commit-hooks;
        packages = packages.${system};
    };

    devShells.${system}.default =
        let
            pkgs = nixpkgs.legacyPackages.${system};
            preCommitCheck = checks.${system}.pre-commit;
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
