#!/bin/sh
set -eu
: "${treeSource:?}" "${previewSource:?}" "${deleteSource:?}" "${touchSource:?}" "${resolveSource:?}" "${out:?}"

root=$(mktemp -d)
trap 'rm -rf "$root"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$root/bin" "$root/repo/sub dir" "$root/runtime/yubikey-touch"
export PATH="$root/bin:$PATH" TEST_ARGS="$root/args" LSD_TREE_SOURCE="$treeSource"
cat > "$root/bin/lsd" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_ARGS"
SH
cat > "$root/bin/lsd-tree" <<'SH'
#!/bin/sh
exec dash "$LSD_TREE_SOURCE" "$@"
SH
chmod +x "$root/bin/lsd" "$root/bin/lsd-tree"
git -C "$root/repo" init --quiet
printf '%s\n' '# comment' '' '*.tmp' 'with space' > "$root/repo/.gitignore"
(
    cd "$root/repo"
    dash "$treeSource" --color=always
)
printf '%s\n' --tree --depth=3 --blocks=date,size,name --color=always \
    '--ignore-glob=*.tmp' '--ignore-glob=with space' > "$root/expected"
cmp "$root/expected" "$TEST_ARGS"
(
    cd "$root"
    dash "$previewSource" "$root/repo/sub dir"
)
printf '%s\n' --tree --depth=3 --blocks=date,size,name --color=always \
    "$root/repo/sub dir" '--ignore-glob=*.tmp' '--ignore-glob=with space' > "$root/expected"
cmp "$root/expected" "$TEST_ARGS"

printf '%s\n' first second third > "$root/history with space"
dash "$deleteSource" second "$root/history with space"
printf '%s\n' first third > "$root/expected"
cmp "$root/expected" "$root/history with space"

export XDG_RUNTIME_DIR="$root/runtime"
if dash "$touchSource" check; then
    printf '%s\n' 'missing touch state passed check' >&2
    exit 1
fi
printf '%s\n' GPG > "$XDG_RUNTIME_DIR/yubikey-touch/active"
dash "$touchSource" check
test "$(dash "$touchSource")" = GPG

printf '%s\n' config > "$root/config-source"
ln -s "$root/config-source" "$root/config"
dash "$resolveSource" "$root/config"
test ! -L "$root/config"
cmp "$root/config-source" "$root/config"
touch "$out"
