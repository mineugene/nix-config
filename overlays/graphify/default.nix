let
    pin = (builtins.fromJSON (builtins.readFile ../pins.json)).graphify;
in
final: prev: {
    graphify = prev.graphify.overridePythonAttrs (_: {
        inherit (pin) version;
        src = prev.fetchFromGitHub {
            inherit (pin) owner repo;
            tag = pin.ref;
            hash = pin.srcHash;
        };
    });
}
