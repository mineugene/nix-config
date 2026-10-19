# Shared lint building blocks exported for consuming flakes. Every helper takes
# the consuming flake's pkgs so a check runs against its own repository root.
{
    preCommitHooks,
}:
let
    scripts = import ./scripts.nix;

    # Hooks every repository runs. Callers merge their own language hooks in.
    sharedHooks = pkgs: {
        convco = {
            enable = true;
        };
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
            # A single invocation receives every file so the wrapper can
            # print one consolidated, sorted failure list.
            entry = "${
                scripts { inherit pkgs; } {
                    name = "prettier-report";
                    src = ./prettier-report.sh;
                }
            }/bin/prettier-report ${pkgs.prettier}/bin/prettier .prettierrc.json";
            require_serial = true;
        };
    };

    mkPreCommit =
        {
            pkgs,
            system,
            src,
            extraHooks ? { },
        }:
        preCommitHooks.lib.${system}.run {
            inherit src;
            hooks = sharedHooks pkgs // extraHooks;
        };

    mkPosixShellCheck =
        {
            pkgs,
            src,
            name ? "posix-shell-check",
        }:
        pkgs.runCommandLocal name {
            nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.dash
                pkgs.findutils
                pkgs.gnused
                pkgs.shellcheck
            ];
            inherit src;
            validator = ./check-posix-shell.sh;
        } (builtins.readFile ./posix-shell-check.sh);

    mkQmlLintCheck =
        {
            pkgs,
            shellConfig,
            name ? "qml-lint-check",
        }:
        pkgs.runCommandLocal name {
            nativeBuildInputs = [
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.qt6.qtdeclarative
            ];
            inherit shellConfig;
            qmlLint = ./qml-lint.sh;
            quickshellModules = "${pkgs.quickshell}/lib/qt-6/qml";
            qtModules = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
        } (builtins.readFile ./qml-lint-check.sh);
in
{
    inherit
        scripts
        mkPreCommit
        mkPosixShellCheck
        mkQmlLintCheck
        ;
    prettierReport = ./prettier-report.sh;
    posixShellValidator = ./check-posix-shell.sh;
    qmlLint = ./qml-lint.sh;
}
