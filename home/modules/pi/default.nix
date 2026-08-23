{
    config,
    lib,
    piDevConfig,
    pkgs,
    ...
}:
let
    jsonFormat = pkgs.formats.json { };
    packageSource = "git:github.com/mineugene/pi-dev-config";
    pidevSettings = config.programs.pi-coding-agent.pidevSettings;
    settingsDefaults = {
        editorPaddingX = 1;
        enableInstallTelemetry = false;
        fullscreenScrollbar = "always";
        hideThinkingBlock = true;
        quietStartup = true;
        theme = "tokyo-night";
        tuiMode = "fullscreen";
        # pi's own trigger is the backstop below pi-dev-config's proactive one, so
        # keep it enabled. keepRecentTokens is raised over pi's 20k default because
        # the proactive trigger fires with headroom left, making a bigger verbatim
        # tail affordable.
        compaction = {
            enabled = true;
            reserveTokens = 16384;
            keepRecentTokens = 24000;
        };
    };
    # github-copilot advertises raw context windows on its OpenAI Responses
    # endpoint, but the backend reserves the model's output allowance from
    # them: gpt-5.6 rejects prompts past roughly 920k of its advertised
    # 1,050,000 with "Your input exceeds the context window of this model".
    # pi never sends max_output_tokens on openai-responses, so it cannot
    # shrink that reservation; the only lever is telling pi the real usable
    # window. Without this, contextTokens > contextWindow - reserveTokens is
    # unreachable and auto-compaction only runs after the API 400.
    # The gpt-6 and mai-code pins extrapolate the same rule (advertised minus
    # the model's 128k output allowance, less margin); revisit them if the
    # backend ever treats those models differently. Claude models need no
    # pin: pi fits anthropic max_tokens under the remaining window per
    # request, so their advertised windows are already honest.
    copilotOverrides = builtins.mapAttrs (_: window: { contextWindow = window; }) {
        "gpt-5.6-terra" = 900000;
        "gpt-5.6-sol" = 900000;
        "gpt-5.6-luna" = 900000;
        "gpt-6-astra" = 850000;
        "gpt-6-sol" = 850000;
        "gpt-6-luna" = 850000;
        "mai-code-1.1-flash" = 120000;
    };
    settingsDir = "${config.home.homeDirectory}/.pi/agent";
    configureSettings = pkgs.writeShellApplication {
        name = "configure-pi-settings";
        runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
        ];
        runtimeEnv = {
            PI_SETTINGS_DEFAULTS = builtins.toJSON settingsDefaults;
            PI_DECLARED_SETTINGS = builtins.toJSON pidevSettings;
            PI_SETTINGS_FILTER = ./settings.jq;
            PI_DECLARED_FILTER = ./declared-settings.jq;
        };
        text = builtins.readFile ./configure-settings.sh;
        # runtimeEnv renders JSON values as quoted assignments, which ShellCheck
        # misreads as attempted word-splitting quotes.
        excludeShellChecks = [
            "SC2089"
            "SC2090"
        ];
    };
in
{
    options.programs.pi-coding-agent.pidevSettings = lib.mkOption {
        inherit (jsonFormat) type;
        default = { };
        description = ''
            pi-dev-config settings written into its writable pidev.json file.
            Each declared top-level key replaces the existing value outright,
            so removing a nested entry here also removes it on activation.
            Undeclared top-level keys are left untouched.
        '';
    };

    config = {
        programs.pi-coding-agent = {
            enable = true;
            extraPackages = [
                pkgs.git
                pkgs.nodejs
                pkgs.rtk
                piDevConfig.packages.${pkgs.stdenv.hostPlatform.system}.default
            ];
            keybindings = builtins.fromJSON (builtins.readFile (piDevConfig + "/keybindings.json"));
            models.providers.github-copilot.modelOverrides = copilotOverrides;
        };

        # Keep settings.json writable so pi can persist model and thinking changes.
        # Home Manager manages keybindings directly, but only merges this package and
        # initial preferences into pi's mutable settings file. pidev.json also stays
        # writable while values declared through pidevSettings remain authoritative.
        home.activation.configurePiDev = lib.hm.dag.entryAfter [ "linkGeneration" ] (
            "run ${lib.getExe configureSettings} ${
                lib.escapeShellArgs [
                    settingsDir
                    packageSource
                ]
            }"
        );
    };
}
