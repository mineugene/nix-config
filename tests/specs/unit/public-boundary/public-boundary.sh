#!/bin/sh
set -eu

: "${src:?}" "${out:?}"

cp -R "$src" source
cd source

gitleaks detect --no-banner --no-git --redact --source .

for private_path in hosts infra secrets .sops.yaml; do
    if [ -e "$private_path" ]; then
        echo "private repository path found: $private_path" >&2
        exit 1
    fi
done

touch "$out"
