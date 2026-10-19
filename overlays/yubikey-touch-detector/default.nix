# Fix upstream's single-shot GPG touch probe missing the first operation
# after a cold agent start (LEARN races ahead of the signing op into
# scdaemon, completes fast, and the touch wait goes unnotified) plus the
# unbuffered check channel dropping requests that arrive mid-check.
# Upstream: https://github.com/maximbaz/yubikey-touch-detector (1.15.0)
let
    pin = (builtins.fromJSON (builtins.readFile ../pins.json)).yubikey-touch-detector;
in
final: prev: {
    yubikey-touch-detector = prev.yubikey-touch-detector.overrideAttrs (old: {
        inherit (pin) version;
        src = prev.fetchFromGitHub {
            inherit (pin) owner repo;
            tag = pin.ref;
            hash = pin.srcHash;
        };
        vendorHash = pin.depHash;
        patches = (old.patches or [ ]) ++ [ ./gpg-probe-retry.patch ];
    });
}
