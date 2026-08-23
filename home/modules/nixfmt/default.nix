{ pkgs, ... }:
{
    xdg.configFile."nixfmt/nixfmt.toml".source = (pkgs.formats.toml { }).generate "nixfmt.toml" {
        indent-size = 4;
    };
}
