{
    pkgs,
    hostConfig ? {
        isWsl = false;
    },
    ...
}:
let
    mkGitScript =
        name:
        pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.git ];
            text = builtins.readFile ./scripts/${name}.sh;
        };
    scripts = map mkGitScript [
        "git-breaking"
        "git-desctag"
        "git-igtrk-purge"
        "git-lgonly"
        "git-unpsf"
    ];
in
{
    home.packages = scripts;
    programs.git = {
        enable = true;

        settings = {
            branch = {
                autoSetupMerge = "simple";
                sort = "-committerdate";
            };
            color.ui = "auto";
            core = {
                autocrlf = if hostConfig.isWsl then "input" else false;
                editor = "nvim";
                filemode = false;
                fsmonitor = false;
            };
            diff.algorithm = "histogram";
            fetch.prune = true;
            init.defaultBranch = "main";
            log.date = "relative";
            merge.conflictStyle = "zdiff3";
            pull = {
                ff = "only";
                rebase = true;
            };
            push = {
                autoSetupRemote = true;
                default = "simple";
            };
            rebase = {
                autoStash = true;
                updateRefs = true;
            };
            rerere.enabled = true;
            tag.sort = "version:refname";

            advice.diverging = false;
            alias = import ./aliases.nix;
        };
    };

}
