final: prev: {
    pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
        # Nerd Font glyphs, spinner frames, and suppressed-thinking layout are
        # applied as fail-loud string substitutions so upstream line drift
        # cannot silently mis-apply them.
        postPatch = (old.postPatch or "") + "\n" + builtins.readFile ./ui-tweaks.sh;
    });
}
