final: prev:
let
    bottom = import ./bottom final prev;
    dotnetTools = import ./dotnet-tools final prev;
    eww = import ./eww final prev;
    fonts = import ./fonts final prev;
    pi = import ./pi final prev;
    yubikeyTouchDetector = import ./yubikey-touch-detector final prev;
in
bottom // dotnetTools // eww // fonts // pi // yubikeyTouchDetector
