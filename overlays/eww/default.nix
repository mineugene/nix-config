final: prev: {
    eww = prev.eww.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./plain-gtk-window.patch ];
    });
}
