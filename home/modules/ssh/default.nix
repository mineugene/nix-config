{ lib, options, ... }:
let
    # home-manager-stable (release-25.11) still exposes only the legacy
    # top-level options (controlMaster etc.); unstable has migrated to the
    # `settings."*"` attrset and deprecates the old names. Branch on which
    # surface is available so the same module loads cleanly on both pins.
    hasSettings = options.programs.ssh ? settings;
in
{
    # Ensure the sockets directory exists so SSH ControlPath does not fail with
    # "unix_listener: cannot bind to path ... No such file or directory"
    home.file.".ssh/sockets/.keep".text = "";

    programs.ssh = lib.mkMerge [
        {
            enable = true;
            enableDefaultConfig = false;
        }
        (lib.optionalAttrs hasSettings {
            settings."*" = {
                AddKeysToAgent = "yes";
                ControlMaster = "auto";
                ControlPath = "~/.ssh/sockets/%r@%h-%p";
                ControlPersist = "10m";
            };
        })
        (lib.optionalAttrs (!hasSettings) {
            matchBlocks."*" = {
                addKeysToAgent = "yes";
                controlMaster = "auto";
                controlPath = "~/.ssh/sockets/%r@%h-%p";
                controlPersist = "10m";
            };
        })
    ];
}
