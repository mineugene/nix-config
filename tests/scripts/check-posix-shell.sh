#!/bin/sh
set -u

status=0

for script do
    first_line=$(head -n 1 "$script") || first_line=
    [ "$first_line" = '#!/bin/sh' ] || continue

    shellcheck --shell=sh "$script" || status=1
    dash -n "$script" || status=1
done

exit "$status"
