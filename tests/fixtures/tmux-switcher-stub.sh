#!/bin/sh
set -eu

command=${0##*/}
root=$TEST_ROOT
case $command in
    fzf)
        cat > "$root/choices"
        printf '%s\n%s\n' "${TEST_KEY:-}" "$TEST_ROW"
        ;;
    zoxide)
        printf '%s\n' "$TEST_DIRS"
        ;;
    tmux)
        terminal=false
        [ ! -t 0 ] || terminal=true
        jq -cn --argjson terminal "$terminal" --args '[$ARGS.positional, $terminal]' -- "$@" >> "$root/calls"
        action=$1
        shift
        case $action in
            list-sessions)
                jq -r 'to_entries[] | "1\t\(.key)\t\(.value)\t1"' "$root/sessions"
                ;;
            has-session)
                while [ "$1" != -t ]; do shift; done
                target=$2
                exact=false
                case $target in =*) exact=true ;; esac
                while [ "${target#=}" != "$target" ]; do target=${target#=}; done
                jq -e --arg target "$target" --argjson exact "$exact" '
                    keys | any(. == $target) or
                    (($exact | not) and any(startswith($target)))
                ' "$root/sessions" >/dev/null
                ;;
            new-session)
                name=
                directory=
                while [ "$#" -gt 0 ]; do
                    case $1 in
                        -s) name=$2; shift ;;
                        -c) directory=$2; shift ;;
                    esac
                    shift
                done
                if [ -n "${TEST_FAIL_CREATE:-}" ] || [ ! -d "$directory" ]; then
                    printf 'create failed\n' >&2
                    exit 1
                fi
                jq --arg name "$name" --arg directory "$directory" '.[$name] = $directory' \
                    "$root/sessions" > "$root/sessions.next"
                mv "$root/sessions.next" "$root/sessions"
                ;;
            attach-session)
                if [ ! -t 0 ]; then
                    printf 'open terminal failed: not a terminal\n' >&2
                    exit 1
                fi
                ;;
        esac
        ;;
esac
