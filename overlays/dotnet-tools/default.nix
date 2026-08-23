final: _prev: {
    easydotnet = final.callPackage ./easydotnet.nix { };
    dotnet-serve = final.callPackage ./dotnet-serve.nix { };
}
