{ pkgs, ... }:
let
    # debugpy build pulls sphinx 9.1+, which requires python >= 3.12
    withDebugpy = py: py.withPackages (ps: [ ps.debugpy ]);

    # Multiple python derivations expose conflicting unversioned symlinks
    # (python3, pip3, pydoc3, ...). The default (pkgs.python3, currently
    # 3.13) keeps them; the rest are stripped to versioned binaries only,
    # so python3.11/3.12/3.14 are still callable. Using pkgs.python3 also
    # dedupes with neovim/dap.nix which references the same alias.
    versioned =
        env: ver:
        pkgs.runCommandLocal "python-${ver}-versioned" { } ''
            mkdir -p $out/bin
            ln -s ${env}/bin/python${ver} $out/bin/python${ver}
        '';
in
{
    home.packages = [
        (withDebugpy pkgs.python3)
        (versioned (withDebugpy pkgs.python314) "3.14")
        (versioned (withDebugpy pkgs.python312) "3.12")
        (versioned pkgs.python311 "3.11")
        pkgs.uv
    ];

    home.sessionVariables = {
        UV_PYTHON_PREFERENCE = "only-system";
    };
}
