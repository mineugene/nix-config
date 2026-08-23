{ lib, pkgs, ... }:
let
    completionPkgs = with pkgs; [
        docker_29
        fd
        jujutsu
        lsd
        ripgrep
    ];

    completionPaths = builtins.concatStringsSep " " (
        map (pkg: "${pkg}/share/zsh/site-functions") (completionPkgs ++ [ gitCompletions ])
    );
    gitCompletions = pkgs.runCommand "git-zsh-completions" { } ''
        mkdir -p $out/share/zsh/site-functions
        cp ${pkgs.git}/share/git/contrib/completion/git-completion.zsh $out/share/zsh/site-functions/_git
        cp ${pkgs.git}/share/git/contrib/completion/git-completion.bash $out/share/zsh/site-functions/git-completion.bash
    '';
in
{
    programs.zsh.initContent = lib.mkOrder 550 ''
        # Add package completion directories to fpath
        fpath=(${completionPaths} $fpath)
    '';
}
