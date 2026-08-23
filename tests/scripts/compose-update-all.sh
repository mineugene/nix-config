#!/bin/sh
set -eu

update_all=$1
tmp=$2
fake_bin=$tmp/bin
log=$tmp/systemctl.log
mkdir -p "$fake_bin"

cat > "$fake_bin/systemctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$COMPOSE_TEST_LOG"
for failed_unit in ${COMPOSE_FAIL_UNITS:-}; do
    [ "$3" != "$failed_unit" ] || exit 1
done
SH
chmod +x "$fake_bin/systemctl"
export PATH="$fake_bin:$PATH"
export COMPOSE_TEST_LOG="$log"

"$update_all" compose-a-update.service compose-b-update.service compose-c-update.service
expected='start --wait compose-a-update.service
start --wait compose-b-update.service
start --wait compose-c-update.service'
[ "$(cat "$log")" = "$expected" ]

: > "$log"
if COMPOSE_FAIL_UNITS=compose-b-update.service \
    "$update_all" compose-a-update.service compose-b-update.service compose-c-update.service; then
    echo 'compose update succeeded after a unit failed' >&2
    exit 1
fi
[ "$(cat "$log")" = "$expected" ]

: > "$log"
if COMPOSE_FAIL_UNITS='compose-a-update.service compose-c-update.service' \
    "$update_all" compose-a-update.service compose-b-update.service compose-c-update.service; then
    echo 'compose update succeeded after multiple units failed' >&2
    exit 1
fi
[ "$(cat "$log")" = "$expected" ]
