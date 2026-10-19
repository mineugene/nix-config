#!/bin/sh

wait_until() {
    test_wait_attempt=0
    until "$@"; do
        test_wait_attempt=$((test_wait_attempt + 1))
        if [ "$test_wait_attempt" -ge "${TEST_WAIT_ATTEMPTS:-600}" ]; then
            printf 'timed out waiting for: %s\n' "$*" >&2
            return 1
        fi
        sleep 0.1
    done
}
