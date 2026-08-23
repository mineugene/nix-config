{
    a = "add";
    aa = "add --all";
    # Commits on this branch not yet in its upstream.
    ahead = "log @{upstream}..HEAD --oneline";
    ap = "add --patch";
    b = "branch";
    bad = "bisect bad";
    bd = "branch --delete";
    bdd = "branch --delete --force";
    # Commits in the upstream not yet in this branch.
    behind = "log HEAD..@{upstream} --oneline";
    bl = "branch --list";
    bla = "branch --remotes";
    ca = "commit --amend";
    cane = "commit --amend --no-edit";
    cfg = "config --list --local";
    cfga = "config --list";
    cfgg = "config --list --global";
    cm = "commit -m";
    cp = "cherry-pick";
    csm = "commit -S -m";
    df = "diff";
    dfs = "diff --staged";
    dfst = "diff --stat";
    # Files changed by a commit, without the commit header or diff content.
    dft = "diff-tree --no-commit-id --name-only -r";
    dfu = "diff @{upstream}";
    f = "fetch";
    fa = "fetch --all --prune";
    good = "bisect good";
    head = "log -1 HEAD";
    headp = "log -1 -p";

    ig = "ls-files --others --ignored --exclude-standard";
    # Print ignored, untracked files as basenames; NUL delimiters handle spaces.
    ig-1 = "!git ls-files --others --ignored --exclude-standard -z | xargs -0 -n1 basename";

    igtrk = "ls-files --cached --ignored --exclude-standard";
    # Print tracked ignored files as basenames; NUL delimiters handle spaces.
    igtrk-1 = "!git ls-files --cached --ignored --exclude-standard -z | xargs -0 -n1 basename";

    lg = "log --oneline";
    lga = "log --oneline --graph --decorate --all";
    # `git lgby AUTHOR`: commits whose author matches AUTHOR.
    lgby = "!f() { git log --oneline --author=\"$1\"; }; f";
    # `git lgcc PREFIX`: commits whose message starts with PREFIX (extended regex).
    lgcc = "!f() { git log --oneline --grep=\"^$1\" --extended-regexp; }; f";
    # `git lgd DIR`: commits that changed files under DIR.
    lgd = "!f() { git log --oneline -- \"$1/\"; }; f";
    # `git lgf FILE`: commits that changed FILE.
    lgf = "!f() { git log --oneline -- \"$1\"; }; f";
    lgg = "log --oneline --graph --decorate";
    # `git lggrep REGEX`: commits whose diffs add or remove a line matching REGEX.
    lggrep = "!f() { git log --oneline -G\"$1\"; }; f";
    lgm = "log --oneline --first-parent --merges";
    # `git lgmsg TEXT`: commits whose messages match TEXT.
    lgmsg = "!f() { git log --oneline --grep=\"$1\"; }; f";
    # `git lgpick TEXT`: commits that add or remove the exact string TEXT.
    lgpick = "!f() { git log --oneline -S\"$1\"; }; f";
    # `git lgsince START END`: commits in the inclusive date range.
    lgsince = "!f() { git log --oneline --after=\"$1\" --before=\"$2\"; }; f";

    mg = "merge";
    mga = "merge --abort";
    mgs = "merge --squash";
    ps = "push";
    psd = "push --delete";
    psf = "push --force-with-lease";
    psff = "push --force";
    pu = "pull";
    purb = "pull --rebase";
    purbst = "pull --rebase --autostash";
    rb = "rebase";
    rba = "rebase --abort";
    rbc = "rebase --continue";
    rbi = "rebase --interactive";
    rbo = "rebase --onto";
    rbs = "rebase --skip";
    rem = "remote -v";
    res = "restore";
    ress = "restore --staged";
    # Restore both index and worktree from HEAD; discards staged and unstaged changes.
    reshead = "restore --source=HEAD --staged --worktree";
    rev = "revert";
    shortlog = "shortlog -sn";
    smi = "submodule init";
    smu = "submodule update";
    st = "status";
    sta = "stash apply";
    stac = "stash clear";
    stad = "stash drop";
    stal = "stash list";
    stap = "stash pop";
    stas = "stash show -p";
    stau = "stash --include-untracked";
    sw = "switch";
    swc = "switch -c";
    swd = "switch --detach";
    # Switch to the previously checked-out branch.
    swp = "switch -";
    unc = "reset --soft HEAD~1";
    # Reset to the previous HEAD reflog entry while keeping index and worktree changes.
    unca = "reset --soft HEAD@{1}";
    # Discard changes since the operation that set ORIG_HEAD.
    undo = "reset --hard ORIG_HEAD";
    wt = "worktree";
    wta = "worktree add";
    wtl = "worktree list";
    wtr = "worktree remove";
    # Remove metadata for worktrees deleted outside Git.
    wtp = "worktree prune";
}
