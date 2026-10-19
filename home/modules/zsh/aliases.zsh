histr() {
    rm -f $HISTFILE && exec zsh "$@"
}

ctop() {
    ps auxf | sort -nr -k3 | head -6 "$@"
}

gpgp() {
    echo test | gpg --clearsign "$@" > /dev/null
}
