{ lib, pkgs, ... }:
{
    home.packages = [ pkgs.rtk ];

    home.sessionVariables.RTK_TELEMETRY_DISABLED = "1";

    home.file.".codex/hooks.json".text = builtins.toJSON {
        description = "Rewrite Codex shell commands through RTK.";
        hooks.PreToolUse = [
            {
                matcher = "^Bash$";
                hooks = [
                    {
                        type = "command";
                        # RTK 0.45 has no Codex handler; this emits Codex-compatible PreToolUse JSON.
                        command = "${pkgs.rtk}/bin/rtk hook claude";
                    }
                ];
            }
        ];
    };

    home.activation.initializeRtk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export RTK_TELEMETRY_DISABLED=1
        run ${pkgs.rtk}/bin/rtk telemetry disable
        run ${pkgs.rtk}/bin/rtk init --global --codex
    '';
}
