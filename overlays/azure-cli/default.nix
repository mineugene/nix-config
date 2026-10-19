_final: prev:
let
    lib = prev.lib;

    # nixpkgs-unstable bumped invoke to 3.x, whose API break makes nixpkgs mark
    # fabric 3.2.3 as broken. azure-cli propagates fabric, so it stops
    # evaluating. Patch fabric with upstream's invoke 3 support (fabric#2376)
    # and relax the runtime dependency metadata that still pins invoke <3.
    fixFabric = _: pyPrev: {
        fabric = pyPrev.fabric.overridePythonAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./fabric-invoke3.patch ];
            pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "invoke" ];
            meta = old.meta // {
                broken = false;
            };
        });
    };

    basePython = prev.python3;

    # azure-cli builds its own interpreter with python3.override, and chained
    # overrides replace packageOverrides instead of composing, so hand it a
    # python whose override re-applies the fabric fix on top of its own.
    fixedPython =
        let
            py = basePython.override { packageOverrides = fixFabric; };
        in
        py
        // {
            override =
                args:
                basePython.override (
                    args
                    // {
                        packageOverrides = lib.composeExtensions (args.packageOverrides or (_: _: { })) fixFabric;
                    }
                );
        };
in
{
    # The condition is lazy so the overlay does not force the python package
    # set while the pkgs fixpoint is being assembled.
    azure-cli =
        if prev.python3.pkgs.fabric.meta.broken or false then
            prev.azure-cli.override { python3 = fixedPython; }
        else
            prev.azure-cli;
}
