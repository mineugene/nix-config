let
    pin = (builtins.fromJSON (builtins.readFile ../pins.json)).bottom;
in
final: prev: {
    bottom = prev.bottom.overrideAttrs (old: {
        inherit (pin) version;
        src = prev.fetchFromGitHub {
            inherit (pin) owner repo;
            tag = pin.ref;
            hash = pin.srcHash;
        };
        cargoHash = pin.depHash;
        patches = (old.patches or [ ]) ++ [ ./basic-view.patch ];
    });
}
