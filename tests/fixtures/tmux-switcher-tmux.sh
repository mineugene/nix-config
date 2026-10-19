#!/bin/sh
exec "$REAL_TMUX" -S "$TEST_SOCKET" -f /dev/null "$@"
