{
    config,
    lib,
    pkgs,
    ...
}:
let
    theme = config.mine.desktop.theme;
in
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
        theme.fonts.interface.package
        theme.fonts.monospace.package
        pkgs.iosevka-etoile-nf
    ];

    # Subpixel rendering produces color fringing on non-stripe OLED layouts
    # and needs a vertical ordering on portrait-rotated panels.
    fonts.fontconfig = {
        enable = true;
        antialiasing = lib.mkDefault true;
        hinting = lib.mkDefault "slight";
        subpixelRendering = lib.mkDefault "none";
        defaultFonts.monospace = [ theme.fonts.monospace.family ];
        defaultFonts.sansSerif = [ theme.fonts.interface.family ];
        defaultFonts.serif = [ "IosevkaEtoileNF" ];
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
        font.name = "${theme.fonts.interface.family} 11";
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
