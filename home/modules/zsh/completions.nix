{ lib, pkgs, ... }:
let
    # Home Manager already adds each profile's site-functions to fpath, so only
    # completions that profiles do not provide are listed here.
    completionPkgs = with pkgs; [
        docker_29
    ];

    completionPaths = builtins.concatStringsSep " " (
        map (pkg: "${pkg}/share/zsh/site-functions") (completionPkgs ++ [ gitCompletions ])
    );
    gitCompletions = pkgs.linkFarm "git-zsh-completions" [
        {
            name = "share/zsh/site-functions/_git";
            path = "${pkgs.git}/share/git/contrib/completion/git-completion.zsh";
        }
        {
            name = "share/zsh/site-functions/git-completion.bash";
            path = "${pkgs.git}/share/git/contrib/completion/git-completion.bash";
        }
    ];
in
{
    programs.zsh.initContent = lib.mkOrder 550 (
        builtins.replaceStrings [ "@completionPaths@" ] [ completionPaths ] (
            builtins.readFile ./completions.zsh
        )
    );
}
