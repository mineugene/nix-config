{ lib, pkgs, ... }:
{
    home.pointerCursor = {
        enable = true;
        package = pkgs.capitaine-cursors;
        name = "capitaine-cursors-white";
        size = 24;
        gtk.enable = true;
    };

    home.packages = [
        pkgs.grim
        pkgs.slurp
        pkgs.wl-clipboard
        pkgs.iosevka-nf
        pkgs.iosevka-term-nf
    ];

    fonts.fontconfig = {
        enable = true;
        defaultFonts.monospace = [ "IosevkaNF" ];
        defaultFonts.sansSerif = [ "IosevkaNF" ];
    };

    home.sessionVariables = {
        BROWSER = "brave";
        GDK_BACKEND = "wayland";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland";
        XDG_CURRENT_DESKTOP = "Hyprland";
    };

    gtk = {
        enable = true;
        font.name = "IosevkaNF 11";
        theme = {
            name = "Adwaita";
            package = pkgs.gnome-themes-extra;
        };
        gtk4.theme = lib.mkDefault null;
    };

    qt = {
        enable = true;
        platformTheme.name = "gtk3";
    };
}
