#!/bin/sh
# The lock shows its prompt on one monitor; an empty name draws it on all.
set -eu

SHELL_LOCK_MONITOR=$(monitor-topology primary 2>/dev/null || true)
export SHELL_LOCK_MONITOR

exec quickshell --no-duplicate --path "${SHELL_LOCK_QML:?SHELL_LOCK_QML must be set}"
