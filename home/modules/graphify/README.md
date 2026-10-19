# Graphify

`homeModules.graphify` installs stock nixpkgs Graphify in an isolated Nix Python
environment. It exposes `graphify` and `graphify-mcp`, without adding global
Python, pip, or pydoc commands. Graphify is pinned in `overlays/pins.json` (see `overlays/graphify`) until nixpkgs ships a release with the Pi guard; remove the overlay then.

```nix
{
    imports = [ public.homeModules.graphify ];
    programs.graphify.enable = true;
}
```

`programs.graphify.package` defaults to `pkgs.graphify`. Select optional
dependencies through the package, keeping user-specific choices downstream:

```nix
{ pkgs, ... }: {
    programs.graphify = {
        enable = true;
        package = pkgs.graphify.overridePythonAttrs (old: {
            dependencies =
                old.dependencies
                ++ old.optional-dependencies.openai
                ++ old.optional-dependencies.watch;
        });
    };
}
```

Set `programs.graphify.piGuard.enable = true` to link the Pi guard extension at
`~/.local/share/graphify/pi-guard`, then run
`pi install ~/.local/share/graphify/pi-guard` once. Pi stores that stable path,
so rebuilds update the target without re-registering.

The MCP entry point needs the package's `mcp` optional dependencies when used.
The module does not enable Pi's Graphify integration or manage credentials.

## Migrating from the overlay

Remove the standalone Graphify package from `home.packages` and enable this
module instead. Preserve any dependency overrides through
`programs.graphify.package`.

After applying the new Home Manager configuration, run this in each repository
where Graphify hooks were installed:

```sh
graphify hook install
```

Reinstalling updates the interpreter pinned in the hooks and the merge driver,
while preserving unrelated hook content. The module does not scan repositories
or rewrite hooks during activation. The old `graphify-python` helper is no
longer installed.

Hooks pin an absolute Nix store interpreter path. Reinstall them after package
updates, before garbage collection removes their old interpreter. Apply a
previous Home Manager generation and reinstall hooks to roll back.

## Validation

```sh
nix build .#checks.x86_64-linux.graphify
```

The check covers extraction with hash-seed re-exec, direct interpreter imports
without inherited Python paths, dependency customization, coexistence with
Python/debugpy, and commit/checkout hook rebuilds under a minimal `PATH`. It also
checks that reinstalling stale hooks preserves unrelated hook content.
