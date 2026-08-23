final: prev:
let
    bottom = prev.bottom.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./bottom/basic-view.patch ];
    });
    dotnetTools = import ./dotnet-tools final prev;
    eww = import ./eww final prev;
    fonts = import ./fonts final prev;
    yubikeyTouchDetector = import ./yubikey-touch-detector final prev;
    piCodingAgent = prev.pi-coding-agent.overrideAttrs (old: {
        patches =
            (old.patches or [
            ]
            )
            ++ [
                ./pi/nerd-font-icons.patch
                ./pi/thinking-display.patch
                ./pi/spinner-animations.patch
            ];
    });
in
dotnetTools
// eww
// fonts
// yubikeyTouchDetector
// {
    inherit bottom;
    pi-coding-agent = piCodingAgent;
}
