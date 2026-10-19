#!/bin/sh
# Lint every QML and JavaScript source in one assembled shell config directory.
# Usage: qml-lint.sh <config-dir> <qt-modules> <quickshell-modules>
set -eu

config=$1
qtModules=$2
quickshellModules=$3

# Quickshell discovers singletons itself; qmllint needs a qmldir that
# declares them before it can resolve references across the directory.
lint_dir=$(mktemp -d)
trap 'rm -rf "$lint_dir"' EXIT
cp "$config"/*.qml "$lint_dir/"
cp "$config"/*.js "$lint_dir/" 2>/dev/null || true
for file in "$lint_dir"/[A-Z]*.qml; do
    name=$(basename "$file" .qml)
    if grep -q '^pragma Singleton' "$file"; then
        printf 'singleton %s 1.0 %s.qml\n' "$name" "$name"
    else
        printf '%s 1.0 %s.qml\n' "$name" "$name"
    fi
done > "$lint_dir/qmldir"

# qmllint exits zero on warnings, so the output is the verdict. Quickshell's
# own types are only partly described to it, so the categories that depend on
# them are off; unresolved types and syntax errors stay on. The singleton
# notice is about the qmldir this writes, and Quickshell's anchor rect is a
# value type qmllint does not model.
verdict=$lint_dir/verdict
for file in "$lint_dir"/*.qml; do
    qmllint --unqualified disable --missing-property disable --uncreatable-type disable \
        -I "$qtModules" -I "$quickshellModules" -I "$lint_dir" "$file" 2>&1 |
        grep -Ev 'not declared as singleton|Type rect is used' |
        grep -E '^(Warning|Error)' >"$verdict" || true
    if [ -s "$verdict" ]; then
        cat "$verdict" >&2
        printf 'qmllint failed: %s\n' "$file" >&2
        exit 1
    fi
done