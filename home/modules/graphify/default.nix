{
    config,
    lib,
    pkgs,
    ...
}:
let
    cfg = config.programs.graphify;
    pythonEnvironment = pkgs.python3.withPackages (ps: [ (ps.toPythonModule cfg.package) ]);
    cli =
        (pkgs.linkFarm "graphify-cli-${cfg.package.version}" (
            map
                (name: {
                    name = "bin/${name}";
                    path = "${pythonEnvironment}/bin/${name}";
                })
                [
                    "graphify"
                    "graphify-mcp"
                ]
        )).overrideAttrs
            (_: {
                pname = "graphify-cli";
                passthru = { inherit pythonEnvironment; };
                meta.mainProgram = "graphify";
            });
in
{
    options.programs.graphify = {
        enable = lib.mkEnableOption "Graphify in an isolated Python environment";
        package = lib.mkPackageOption pkgs "graphify" { };
        piGuard.enable = lib.mkEnableOption ''
            a stable symlink to Graphify's Pi guard extension at
            `~/.local/share/graphify/pi-guard`. Register it once with
            `pi install ~/.local/share/graphify/pi-guard`; the link follows package
            updates, so the registered path never changes.
            Requires a Graphify release that ships the guard (0.9.92 or later)
        '';
    };

    config = lib.mkIf cfg.enable {
        home.packages = [ cli ];
        home.file.".local/share/graphify/pi-guard" = lib.mkIf cfg.piGuard.enable {
            source = "${cfg.package}/${pkgs.python3.sitePackages}/graphify/pi";
        };
    };
}
