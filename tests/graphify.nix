{ pkgs }:
pkgs.runCommandLocal "graphify-hook-check"
    {
        nativeBuildInputs = [
            pkgs.git
            pkgs.graphify
        ];
    }
    ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME" repo
        cd repo
        git init --quiet

        graphify-python -c 'import graphify.watch'
        graphify hook install

        grep -F "_PINNED='${pkgs.graphify}/bin/graphify-python'" .git/hooks/post-commit
        grep -F "_PINNED='${pkgs.graphify}/bin/graphify-python'" .git/hooks/post-checkout

        touch "$out"
    ''
