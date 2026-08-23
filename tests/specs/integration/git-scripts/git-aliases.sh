#!/bin/sh
set -eu

aliases=$1
root=$2
mkdir -p "$root/home" "$root/repo/dir"
export HOME="$root/home" GIT_CONFIG_NOSYSTEM=1
cd "$root/repo"
git init -q
git config user.name 'Alias Test'
git config user.email aliases@example.invalid
jq -r 'to_entries[] | [.key, .value] | @tsv' "$aliases" |
    while IFS="$(printf '\t')" read -r name value; do
        git config "alias.$name" "$value"
    done
printf '%s\n' first > dir/file
git add dir/file
GIT_AUTHOR_DATE='2001-01-02T12:00:00Z' GIT_COMMITTER_DATE='2001-01-02T12:00:00Z' \
    git commit -qm 'feat: first'
first=$(git log -1 --oneline)
printf '%s\n' second > file
git add file
GIT_AUTHOR_DATE='2001-01-04T12:00:00Z' GIT_COMMITTER_DATE='2001-01-04T12:00:00Z' \
    git commit -qm 'fix: second'
second=$(git log -1 --oneline)
test "$(git lgby 'Alias Test')" = "$(git log --oneline)"
test "$(git lgcc 'feat:')" = "$first"
test "$(git lgd dir)" = "$first"
test "$(git lgf dir/file)" = "$first"
test "$(git lggrep first)" = "$first"
test "$(git lgmsg 'feat: first')" = "$first"
test "$(git lgpick first)" = "$first"
test "$(git lgsince 2001-01-03 2001-01-05)" = "$second"

printf '%s\n' '*.ignored' > .gitignore
printf '%s\n' tracked > 'tracked name.ignored'
printf '%s\n' untracked > 'untracked name.ignored'
git add -f 'tracked name.ignored'
test "$(git ig-1)" = 'untracked name.ignored'
test "$(git igtrk-1)" = 'tracked name.ignored'
git snap
archive=$(find . -name 'repo-*.tar.gz' -print)
test -n "$archive"
tar -tzf "$archive" | grep -Fx 'dir/file'
