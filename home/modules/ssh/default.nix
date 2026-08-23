{ lib, options, ... }:
let
    # The Home Manager pins expose different SSH schemas: stable uses
    # top-level options (controlMaster etc.), while unstable uses the
    # `settings."*"` attrset. Detect the available schema so the module
    # evaluates on both pins.
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
