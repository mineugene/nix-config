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
    };

    config = lib.mkIf cfg.enable {
        home.packages = [ cli ];
    };
}
