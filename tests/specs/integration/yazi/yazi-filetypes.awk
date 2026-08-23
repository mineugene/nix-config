/^\[filetype\]$/ { in_filetype = 1; next }
/^\[/ { in_filetype = 0 }
in_filetype && /^[[:space:]]*\{/ {
    if ($0 !~ /url[[:space:]]*=|mime[[:space:]]*=/) {
        print "filetype rule without url or mime: " $0 > "/dev/stderr"
        bad = 1
    }
}
END { exit bad }
