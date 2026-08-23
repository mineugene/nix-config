# List available recipes.
default:
	@just --list

# Run every flake check and print build logs on failure.
[group('maintenance')]
check:
	nix flake check --print-build-logs

# Scan the public repository for private paths and leaked secrets.
[group('maintenance')]
boundary:
	nix build --no-link --print-build-logs .#checks.x86_64-linux.boundary

# Update all inputs, or only the named input(s).
[group('maintenance')]
update *input:
	nix flake update {{ input }}

# Run all pre-commit checks, using the cached direnv shell when available.
[group('maintenance')]
lint:
	if command -v direnv >/dev/null; then direnv exec . pre-commit run --all-files; else nix develop --command pre-commit run --all-files; fi

# Format tracked files, then run all pre-commit checks.
[group('maintenance')]
fmt:
	if command -v direnv >/dev/null; then direnv exec . just _fmt; else nix develop --command just _fmt; fi

# Format tracked files from inside the development shell.
[private]
_fmt:
	git ls-files -z '*.nix' | xargs -0 --no-run-if-empty nixfmt --indent=4
	tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT && unexpand --first-only --tabs=4 justfile > "$tmp" && cat "$tmp" > justfile
	git ls-files -z | xargs -0 --no-run-if-empty prettier --write --ignore-unknown --
	pre-commit run --all-files

# Remove local Nix build links and the direnv cache.
[group('maintenance')]
clean:
	rm -rf result result-* .direnv
