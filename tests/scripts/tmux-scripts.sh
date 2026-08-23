#!/bin/sh
set -eu

shorten_path=$1
display_name=$2
yubikey_touch=$3
tmp=$4

assert_output() {
    expected=$1
    shift
    actual=$("$@")
    if [ "$actual" != "$expected" ]; then
        printf 'expected "%s", got "%s"\n' "$expected" "$actual" >&2
        exit 1
    fi
}

mkdir -p "$tmp/home/projects/short" "$tmp/outside/one/two/three"
tilde='~'
assert_output "$tilde/projects/short" env HOME="$tmp/home" "$shorten_path" "$tmp/home/projects/short"
assert_output '…/one/two/three' env HOME="$tmp/home" "$shorten_path" "$tmp/outside/one/two/three"
assert_output '/tmp/a' env -u HOME "$shorten_path" /tmp/a

repo="$tmp/repo with space"
mkdir -p "$repo/dir with space"
git init -q "$repo"
assert_output 'repo with space/dir with space' env HOME="$tmp/home" "$shorten_path" "$repo/dir with space"

fake_bin="$tmp/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/shorten-path" <<'SH'
#!/bin/sh
printf 'short:%s' "$1"
SH
chmod +x "$fake_bin/shorten-path"

assert_output 'short:/path with space' env PATH="$fake_bin:$PATH" "$display_name" zsh '/path with space'
assert_output 'server logs' env PATH="$fake_bin:$PATH" "$display_name" 'server logs' /unused
assert_output '12345678901234567890123456789012' env PATH="$fake_bin:$PATH" \
    "$display_name" 12345678901234567890123456789012 /unused
assert_output '...efghijklmnopqrstuvwxyzABCDEFG' env PATH="$fake_bin:$PATH" \
    "$display_name" abcdefghijklmnopqrstuvwxyzABCDEFG /unused
assert_output 'λ window' env PATH="$fake_bin:$PATH" "$display_name" 'λ window' /unused
assert_output '' env PATH="$fake_bin:$PATH" "$display_name" '' ''

runtime_dir="$tmp/runtime"
state_dir="$runtime_dir/yubikey-touch"
mkdir -p "$state_dir"
assert_output '' env XDG_RUNTIME_DIR="$runtime_dir" "$yubikey_touch"
: > "$state_dir/active"
assert_output '' env XDG_RUNTIME_DIR="$runtime_dir" "$yubikey_touch"
printf '%s\n' 'GPG signing' > "$state_dir/active"
assert_output '#[fg=#f7768e,bg=#1a1b26,blink]#[fg=#f7768e,bg=#1a1b26,reverse,blink] TOUCH YK GPG signing #[noreverse]#[fg=#f7768e,bg=#1a1b26,blink]#[default,noblink] ' \
    env XDG_RUNTIME_DIR="$runtime_dir" "$yubikey_touch"
chmod 000 "$state_dir/active"
assert_output '' env XDG_RUNTIME_DIR="$runtime_dir" "$yubikey_touch"
