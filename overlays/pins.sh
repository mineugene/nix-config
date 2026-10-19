#!/bin/sh
# shellcheck disable=SC2016  # jq filters use literal $name/$version, not shell expansion
set -eu

# Maintenance for packages pinned in overlays/pins.json. `outdated` compares each
# pin to upstream; `update` bumps one pin and recomputes its fixed-output hashes.

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
pins=$root/overlays/pins.json
system=x86_64-linux

usage() {
    printf 'usage: pins.sh {outdated|update <name> [version]}\n' >&2
    exit 2
}

api() {
    curl -fsSL "https://api.github.com/repos/$1/$2/$3"
}

fake_hash() {
    nix eval --impure --raw --expr "let f = builtins.getFlake (toString \"$root\"); in f.inputs.nixpkgs.lib.fakeHash"
}

repo_info() {
    curl -fsSL "https://api.github.com/repos/$1/$2"
}

latest_tag() {
    tag=$(api "$1" "$2" releases/latest | jq -r '.tag_name // empty')
    if [ -z "$tag" ]; then
        tag=$(api "$1" "$2" tags | jq -r '.[0].name // empty')
    fi
    printf '%s' "$tag"
}

pin() {
    jq -r --arg name "$1" --arg field "$2" '.[$name][$field] // empty' "$pins"
}

write() {
    jq --indent 4 "$@" "$pins" | unexpand --first-only --tabs=4 > "$pins.tmp"
    mv "$pins.tmp" "$pins"
}

got_hash() {
    sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\)[[:space:]]*$/\1/p' | head -n 1
}

nix_build() {
    nix build --no-link --impure --expr "$1" 2>&1 || true
}

src_expr() {
    printf 'let f = builtins.getFlake (toString "%s"); pkgs = import f.inputs.nixpkgs { system = "%s"; }; in pkgs.fetchFromGitHub { owner = "%s"; repo = "%s"; %s = "%s"; hash = "%s"; }' \
        "$root" "$system" "$1" "$2" "$3" "$4" "$fake"
}

pkg_expr() {
    printf 'let f = builtins.getFlake (toString "%s"); pkgs = import f.inputs.nixpkgs { system = "%s"; overlays = [ f.overlays.default ]; }; in pkgs.%s' \
        "$root" "$system" "$1"
}

do_outdated() {
    status=0
    printf '%-24s %-28s %-28s %s\n' package pinned latest status
    while IFS= read -r name; do
        owner=$(pin "$name" owner)
        repo=$(pin "$name" repo)
        mode=$(pin "$name" mode)
        prefix=$(pin "$name" tagPrefix)
        current=$(pin "$name" version)
        if [ "$mode" = tag ]; then
            tag=$(latest_tag "$owner" "$repo")
            latest=${tag#"$prefix"}
            if [ "$current" = "$latest" ]; then
                mark=ok
            else
                mark=OUTDATED
                status=1
            fi
            printf '%-24s %-28s %-28s %s\n' "$name" "$current" "$latest" "$mark"
        else
            ref=$(pin "$name" ref)
            branch=$(repo_info "$owner" "$repo" | jq -r '.default_branch')
            head=$(api "$owner" "$repo" "commits/$branch" | jq -r '.sha')
            if [ "$ref" = "$head" ]; then
                mark=ok
            else
                mark=OUTDATED
                status=1
            fi
            printf '%-24s %-28s %-28s %s\n' "$name" "$(printf '%s' "$ref" | cut -c1-12)" "$(printf '%s' "$head" | cut -c1-12)" "$mark"
        fi
    done <<EOF
$(jq -r 'keys[]' "$pins")
EOF
    exit "$status"
}

do_update() {
    name=$1
    want=${2:-}
    if ! jq -e --arg name "$name" 'has($name)' "$pins" >/dev/null; then
        printf 'pins: unknown package: %s\n' "$name" >&2
        exit 2
    fi
    owner=$(pin "$name" owner)
    repo=$(pin "$name" repo)
    mode=$(pin "$name" mode)
    prefix=$(pin "$name" tagPrefix)

    backup=$pins.pins.bak
    cp "$pins" "$backup"
    committed=
    restore() {
        if [ -n "$committed" ]; then
            rm -f "$backup"
        else
            mv "$backup" "$pins"
            printf 'pins: restored %s after failure\n' "$pins" >&2
        fi
    }
    trap restore EXIT

    if [ "$mode" = tag ]; then
        if [ -n "$want" ]; then
            ref=$prefix$want
        else
            ref=$(latest_tag "$owner" "$repo")
        fi
        version=${ref#"$prefix"}
        kind=tag
    else
        branch=$(repo_info "$owner" "$repo" | jq -r '.default_branch')
        commit=$(api "$owner" "$repo" "commits/$branch")
        ref=$(printf '%s' "$commit" | jq -r '.sha')
        date=$(printf '%s' "$commit" | jq -r '.commit.committer.date' | cut -c1-10)
        base=$(pin "$name" version | sed 's/-unstable-.*//')
        version=$base-unstable-$date
        kind=rev
    fi
    printf 'pins: %s -> %s (%s)\n' "$name" "$version" "$ref"

    fake=$(fake_hash)
    got=$(nix_build "$(src_expr "$owner" "$repo" "$kind" "$ref")" | got_hash)
    if [ -z "$got" ]; then
        printf 'pins: could not resolve the source hash for %s at %s\n' "$name" "$ref" >&2
        exit 1
    fi
    write --arg name "$name" --arg version "$version" --arg ref "$ref" --arg hash "$got" \
        '.[$name].version = $version | .[$name].ref = $ref | .[$name].srcHash = $hash'

    if jq -e --arg name "$name" '.[$name] | has("depHash")' "$pins" >/dev/null; then
        write --arg name "$name" --arg hash "$fake" '.[$name].depHash = $hash'
        while grep -q "$fake" "$pins"; do
            log=$(nix_build "$(pkg_expr "$name")")
            got=$(printf '%s\n' "$log" | got_hash)
            if [ -z "$got" ]; then
                printf '%s\n' "$log" >&2
                printf 'pins: build failed before the dependency hash resolved; the patch likely needs rebasing\n' >&2
                exit 1
            fi
            write --arg name "$name" --arg hash "$got" '.[$name].depHash = $hash'
        done
    fi

    committed=1
    printf 'pins: %s updated; rebase the patch if it conflicted, then run: just check-fast\n' "$name"
}

case ${1:-} in
    outdated)
        do_outdated
        ;;
    update)
        [ $# -ge 2 ] || usage
        do_update "$2" "${3:-}"
        ;;
    *)
        usage
        ;;
esac
