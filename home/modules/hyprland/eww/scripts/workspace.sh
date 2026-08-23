if (( $# != 1 )); then
    printf 'usage: eww-workspace 1..9\n' >&2
    exit 2
fi

case $1 in
    [1-9]) exec hyprctl dispatch workspace "$1" ;;
    *)
        printf 'eww-workspace: invalid workspace: %s\n' "$1" >&2
        exit 2
        ;;
esac
