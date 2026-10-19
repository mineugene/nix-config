let
    pin = (builtins.fromJSON (builtins.readFile ../pins.json)).eww;
in
final: prev: {
    eww = prev.eww.overrideAttrs (old: {
        inherit (pin) version;
        src = prev.fetchFromGitHub {
            inherit (pin) owner repo;
            rev = pin.ref;
            hash = pin.srcHash;
        };
        cargoHash = pin.depHash;
        patches = (old.patches or [ ]) ++ [ ./plain-gtk-window.patch ];
    });
}
