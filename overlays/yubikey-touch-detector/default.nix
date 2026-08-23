# Fix upstream's single-shot GPG touch probe missing the first operation
# after a cold agent start (LEARN races ahead of the signing op into
# scdaemon, completes fast, and the touch wait goes unnotified) plus the
# unbuffered check channel dropping requests that arrive mid-check.
# Upstream: https://github.com/maximbaz/yubikey-touch-detector (1.13.0)
final: prev: {
    yubikey-touch-detector = prev.yubikey-touch-detector.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./gpg-probe-retry.patch ];
    });
}
