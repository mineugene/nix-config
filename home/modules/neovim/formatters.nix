{ pkgs, lib, ... }:
let
    formatters = with pkgs; {
        nixfmt = {
            pkg = nixfmt;
            args = [ "--indent=4" ];
        };
    };

    formatterFiles = lib.mapAttrs' (
        name: formatter:
        lib.nameValuePair "nvim/formatters/${name}.json" {
            force = true;
            text = builtins.toJSON {
                cmd = baseNameOf (lib.getExe formatter.pkg);
                args = formatter.args or [ ];
            };
        }
    ) formatters;
in
{
    home.packages = lib.mapAttrsToList (_: formatter: formatter.pkg) formatters;

    xdg.dataFile = formatterFiles;
}
