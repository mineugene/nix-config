{
    config,
    pkgs,
    lib,
    ...
}:
let
    lspServers = with pkgs; {
        lua_ls = {
            pkg = lua-language-server;
            settings = {
                Lua = {
                    runtime.version = "LuaJIT";
                    workspace.library = [ "${pkgs.neovim}/share/nvim/runtime" ];
                };
            };
        };
        nixd = {
            pkg = nixd;
            settings = {
                nixd = { };
            };
        };
    };

    lspFiles = lib.mapAttrs' (
        name: server:
        lib.nameValuePair "nvim/lsp/${name}.json" {
            force = true;
            text = builtins.toJSON (
                {
                    cmd = [ (baseNameOf (lib.getExe server.pkg)) ] ++ (server.extraArgs or [ ]);
                }
                // lib.optionalAttrs (server ? settings) { inherit (server) settings; }
            );
        }
    ) lspServers;
in
{
    home.packages = lib.mapAttrsToList (_: server: server.pkg) lspServers;
    home.sessionVariables.OMNISHARPHOME = "${config.xdg.configHome}/omnisharp";

    xdg.dataFile = lspFiles;
}
