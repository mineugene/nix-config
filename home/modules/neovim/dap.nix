{ pkgs, lib, ... }:
let
    dapAdapters = with pkgs; {
        coreclr = {
            pkg = netcoredbg;
            type = "executable";
            extraArgs = [ "--interpreter=vscode" ];
        };
        lldb = {
            pkg = lldb;
            bin = "lldb-dap";
            type = "executable";
        };
        js = {
            pkg = vscode-js-debug;
            bin = "js-debug-adapter";
            type = "server";
            port = "\${port}";
        };
        debugpy = {
            pkg = python3.withPackages (pythonPackages: [ pythonPackages.debugpy ]);
            bin = "python3";
            type = "executable";
            extraArgs = [
                "-m"
                "debugpy.adapter"
            ];
        };
        delve = {
            pkg = delve;
            bin = "dlv";
            type = "server";
            extraArgs = [
                "dap"
                "-l"
                "127.0.0.1:\${port}"
            ];
            port = "\${port}";
        };
    };

    dapFiles = lib.mapAttrs' (
        name: adapter:
        lib.nameValuePair "nvim/dap/${name}.json" {
            force = true;
            text = builtins.toJSON (
                {
                    inherit (adapter) type;
                    command = adapter.bin or adapter.pkg.meta.mainProgram or name;
                    args = adapter.extraArgs or [ ];
                }
                // lib.optionalAttrs (adapter ? port) {
                    inherit (adapter) port;
                }
            );
        }
    ) dapAdapters;
in
{
    home.packages = lib.mapAttrsToList (_: adapter: adapter.pkg) dapAdapters;

    xdg.dataFile = dapFiles;
}
