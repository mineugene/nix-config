final: prev:
let
    fonts = import ./fonts final prev;
    yubikeyTouchDetector = import ./yubikey-touch-detector final prev;
    piCodingAgent = prev.pi-coding-agent.overrideAttrs (old: {
        patches =
            (old.patches or [
            ]
            )
            ++ [
                ./pi-coding-agent-nerd-font-icons.patch
                ./pi-thinking-display.patch
            ];
    });
in
fonts // yubikeyTouchDetector // { pi-coding-agent = piCodingAgent; }
