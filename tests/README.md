# Tests

```text
tests/
  specs/
    unit/
    integration/
    e2e/
  fixtures/
  support/
```

## Placement

- `specs/unit/`: isolated source helpers, configuration assertions, and static repository guards.
- `specs/integration/`: module evaluation, generated configuration, packaged tools, and selected Home Manager activation entries working together.
- `specs/e2e/`: complete runtime workflows. `service-lifecycle` boots a NixOS VM and exercises Compose services with Docker and systemd.
- `fixtures/`: sample inputs, fake commands, and stub services. Executable fixtures simulate dependencies; they do not own test assertions.
- `support/`: shared helpers and validation infrastructure, including readiness polling and shell, Zsh, and embedded-source validators.

Group specs by feature. Keep each feature's `default.nix` beside its shell,
Python, Lua, Zsh, or other test sources. Additional checks for the same feature
may use another Nix file, such as `specs/integration/eww/runtime.nix`.
Assertions belong in `specs/`, not `support/`, regardless of their language.

## Running checks

`outputs/checks.nix` explicitly registers checks and supplies module
configurations. Directory placement does not control discovery or change
public check names.

From the repository root:

```sh
nix build --no-link --print-build-logs .#checks.x86_64-linux.pi-settings
just check-fast
just check
```

`just check-fast` excludes full font builds but includes the VM-backed end-to-end
check. `just check` runs every flake check.
