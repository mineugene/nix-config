#!/bin/sh
set -eu

git_breaking=$1
git_desctag=$2
git_igtrk_purge=$3
git_lgonly=$4
git_unpsf=$5
tmp=$6

export HOME="$tmp/home"
export GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$tmp/repo"
cd "$tmp/repo"
git init -q
git config user.name Test
git config user.email test@example.invalid

printf '%s\n' base > file
git add file
git commit -qm 'chore: base'
printf '%s\n' feature >> file
git commit -am 'feat!: incompatible feature' -q
printf '%s\n' footer >> file
cat > message <<'EOF'
fix: compatible subject

BREAKING CHANGE: incompatible footer
EOF
git add file
git commit -q -F message

expected='fix: compatible subject
feat!: incompatible feature'
[ "$("$git_breaking" 2)" = "$expected" ]
[ "$("$git_breaking" HEAD~2..HEAD)" = "$expected" ]

if "$git_desctag" >/dev/null 2>&1; then
    printf '%s\n' 'git-desctag accepted a repository without tags' >&2
    exit 1
fi
git tag v2.0.0 HEAD
[ "$("$git_desctag")" = v2.0.0 ]

printf '%s\n' ignored.txt > .gitignore
printf '%s\n' ignored > ignored.txt
git add .gitignore
git add -f ignored.txt
git commit -qm 'test: tracked ignored file'
"$git_igtrk_purge" --force
if git ls-files --error-unmatch ignored.txt >/dev/null 2>&1; then
    printf '%s\n' 'git-igtrk-purge retained the ignored file in the index' >&2
    exit 1
fi
[ -f ignored.txt ]

git clone --bare -q . "$tmp/origin.git"
git remote add origin "$tmp/origin.git"
git fetch -q origin
git remote set-head origin -a

git commit --allow-empty -qm 'feat: local only'
[ "$("$git_lgonly")" = "$(git log -1 --format='%h feat: local only')" ]

previous_head=$(git rev-parse HEAD)
git commit --allow-empty -qm 'fix: current head'
printf 'y\n' | "$git_unpsf"
[ "$(git --git-dir="$tmp/origin.git" rev-parse refs/heads/master)" = "$previous_head" ]
