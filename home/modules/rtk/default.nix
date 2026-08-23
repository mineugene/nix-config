{
    config,
    lib,
    pkgs,
    ...
}:
{
    home.packages = [ pkgs.rtk ];

    home.sessionVariables.RTK_TELEMETRY_DISABLED = "1";

    home.file.".codex/hooks.json".text = builtins.toJSON {
        hooks.PreToolUse = [
            {
                matcher = "Bash";
                hooks = [
                    {
                        type = "command";
                        command = "${pkgs.rtk}/bin/rtk hook codex";
                    }
                ];
            }
        ];
    };

    # Mirrors what `rtk init --codex` writes; kept declarative so rtk never
    # mutates files under ~/.codex during activation.
    home.file.".codex/RTK.md".source = ./RTK.md;
    home.file.".codex/AGENTS.md".source = pkgs.replaceVars ./AGENTS.md.in {
        homeDirectory = config.home.homeDirectory;
    };

    home.activation.rtkTelemetry = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        "run ${lib.getExe' pkgs.coreutils "env"} RTK_TELEMETRY_DISABLED=1 ${lib.getExe pkgs.rtk} telemetry disable"
    );
}
