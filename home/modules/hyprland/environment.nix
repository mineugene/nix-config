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
        # gnome-themes-extra supplies only GTK2/3 Adwaita. Forcing GTK4's
        # built-in Adwaita prevents Home Manager generating an import to a
        # non-existent gtk-4.0/gtk.css when downstream sets gtk4.theme = gtk.theme.
        gtk4.theme = lib.mkForce null;
    };

    qt = {
        enable = true;
        platformTheme.name = "gtk3";
    };
}
