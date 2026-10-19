zstyle ':completion:*' menu select
[[ -d $ZSH_COMPDUMP ]] || mkdir -p $ZSH_COMPDUMP
zstyle :compinstall filename "$ZDOTDIR/zshrc"
autoload -Uz compinit

# -C trusts the dump without rescanning fpath; a new zsh version
# starts a fresh dump file.
compinit -C -d "$ZSH_COMPDUMP/zcompdump-${ZSH_VERSION}"
