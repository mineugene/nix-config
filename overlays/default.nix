final: prev:
let
    bottom = prev.bottom.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./bottom/basic-view.patch ];
    });
    eww = import ./eww final prev;
    fonts = import ./fonts final prev;
    graphify = import ./graphify final prev;
    yubikeyTouchDetector = import ./yubikey-touch-detector final prev;
    # The icon patch rewrites the exact upstream statements around the
    # replacements, and 0.99 changed Text to ThemedText in two of them, so
    # the correct variant is picked per pinned version.
    piIconPatch =
        if prev.lib.versionAtLeast (prev.pi-coding-agent.version or "0") "0.99" then
            ./pi-coding-agent-nerd-font-icons-0.99.patch
        else
            ./pi-coding-agent-nerd-font-icons.patch;
    piCodingAgent = prev.pi-coding-agent.overrideAttrs (old: {
        patches =
            (old.patches or [
            ]
            )
            ++ [
                piIconPatch
                ./pi-thinking-display.patch
                ./pi-spinner-animations.patch
            ];
    });
in
eww
// fonts
// graphify
// yubikeyTouchDetector
// {
    inherit bottom;
    pi-coding-agent = piCodingAgent;
}
