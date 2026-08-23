{
    programs.zsh.shellAliases = {
        df = "df -h --exclude-type=tmpfs --exclude-type=devtmpfs";
        dir = "dir -lhA --color=always --group-directories-first";
        egrep = "egrep --color=auto";
        fgrep = "fgrep --color=auto";
        grep = "grep --color=auto";

        cp = "cp --interactive";
        mv = "mv --interactive";
        rm = "rm --interactive=always";

        rand4 = "shuf -i 1000-9999 -n 1 --random-source=/dev/urandom";

        histr = "rm -f $HISTFILE && exec zsh";
        histe = "$EDITOR $HISTFILE";
        ctop = "ps auxf | sort -nr -k3 | head -6";
        enabled = "systemctl list-unit-files --state=enabled";
        gpgls = "gpg --list-keys --keyid-format=LONG";
        gpglsa = "gpg --list-secret-keys --keyid-format=LONG";
        gpgp = "echo test | gpg --clearsign > /dev/null";
    };
}
