#!/usr/bin/env bash
# Show the most recent tag reachable from the current commit.
# Exits gracefully if no tags exist in the repository.

latest=$(git rev-list --tags --max-count=1 2>/dev/null)

if [[ -z "$latest" ]]; then
    echo "No tags found." >&2
    exit 1
fi

git describe --tags "$latest"
