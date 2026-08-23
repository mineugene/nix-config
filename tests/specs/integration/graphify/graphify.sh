#!/bin/sh
set -eu
: "${homePath:?}" "${homeImports:?}" "${graphify:?}" "${minimalPath:?}" "${python:?}" "${graphifyImports:?}"
: "${initialModule:?}" "${changedModule:?}" "${hookBefore:?}" "${hookAfter:?}" "${out:?}" "${waitHelpers:?}"
# shellcheck source=/dev/null
. "$waitHelpers"
export HOME="$TMPDIR/home"
unset PYTHONPATH PYTHONHASHSEED PYTEST_CURRENT_TEST
mkdir -p "$HOME" repo
cd repo || exit 1
git init --quiet
git config user.name 'Graphify Check'
git config user.email 'graphify-check@example.invalid'

test -x "$homePath"/bin/graphify
test -x "$homePath"/bin/graphify-mcp
test -x "$homePath"/bin/python3
"$homePath"/bin/python3 "$homeImports"
test ! -e "$graphify/bin/python3"
env -i HOME="$HOME" PATH="$minimalPath" "$python" "$graphifyImports"

cat "$initialModule" > mod.py
git add mod.py
git commit --quiet -m initial
initial=$(git rev-parse HEAD)
graphify . > "$TMPDIR/extract.log" 2>&1 || { cat "$TMPDIR/extract.log"; exit 1; }
jq -e '.nodes | length > 0' graphify-out/graph.json >/dev/null

for hook in post-commit post-checkout; do
    cat "$hookBefore" > ".git/hooks/$hook"
    chmod +x ".git/hooks/$hook"
done
graphify hook install
for hook in post-commit post-checkout; do
    tail -n +2 "$hookAfter" >> ".git/hooks/$hook"
    substituteInPlace ".git/hooks/$hook" \
        --replace-fail "$python" '/nix/store/obsolete-graphify-python'
done
graphify hook install
graph_matches() {
    jq -e --argjson expected "$1" \
        '([.nodes[] | select(.label == "changed()")] | length > 0) == $expected' \
        graphify-out/graph.json >/dev/null 2>&1
}
wait_for_graph() {
    TEST_WAIT_ATTEMPTS=1800 wait_until graph_matches "$1" || {
        cat "$HOME/.cache/graphify-rebuild.log" >&2
        exit 1
    }
}

cat "$changedModule" >> mod.py
git add mod.py
env -i HOME="$HOME" PATH="$minimalPath" GRAPHIFY_MAX_WORKERS=1 GRAPHIFY_REBUILD_TIMEOUT=120 \
    git commit --quiet -m changed > "$TMPDIR/commit.log" 2>&1 || { cat "$TMPDIR/commit.log"; exit 1; }
wait_for_graph true

env -i HOME="$HOME" PATH="$minimalPath" GRAPHIFY_MAX_WORKERS=1 GRAPHIFY_REBUILD_TIMEOUT=120 GRAPHIFY_FORCE=1 \
    git checkout --quiet "$initial" > "$TMPDIR/checkout.log" 2>&1 || { cat "$TMPDIR/checkout.log"; exit 1; }
wait_for_graph false
printf 'before\nafter\nbefore\nafter\n' > "$TMPDIR/expected-hooks"
cmp "$TMPDIR/expected-hooks" "$HOME/unrelated-hooks"

touch "$out"
