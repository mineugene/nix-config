final: prev:
let
    azureCli = import ./azure-cli final prev;
    bottom = import ./bottom final prev;
    dotnetTools = import ./dotnet-tools final prev;
    fonts = import ./fonts final prev;
    graphify = import ./graphify final prev;
    pi = import ./pi final prev;
    yubikeyTouchDetector = import ./yubikey-touch-detector final prev;
in
azureCli // bottom // dotnetTools // fonts // graphify // pi // yubikeyTouchDetector
