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
    pidevSettingsJson = builtins.toJSON pidevSettings;
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
    # github-copilot advertises a 1,050,000-token window for the gpt-5.6 models,
    # but the backend reserves the model's 128k output allowance from it and
    # rejects prompts past roughly 920k with "Your input exceeds the context window
    # of this model". pi never sends max_output_tokens on openai-responses, so it
    # cannot shrink that reservation; the only lever is telling pi the real usable
    # window. Without this, contextTokens > contextWindow - reserveTokens
    # (1,033,616) is unreachable and auto-compaction only runs after the API 400.
    copilotContextWindow = 900000;
    copilotOverrides = lib.genAttrs [ "gpt-5.6-terra" "gpt-5.6-sol" "gpt-5.6-luna" ] (_: {
        contextWindow = copilotContextWindow;
    });
    settingsDefaultsJson = builtins.toJSON settingsDefaults;
    settingsDir = "${config.home.homeDirectory}/.pi/agent";
    pidevPath = "${settingsDir}/pidev.json";
    settingsPath = "${settingsDir}/settings.json";
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
        home.activation.configurePiDev = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            settingsDir=${lib.escapeShellArg settingsDir}
            settingsPath=${lib.escapeShellArg settingsPath}
            pidevPath=${lib.escapeShellArg pidevPath}
            packageSource=${lib.escapeShellArg packageSource}

            if [[ -v DRY_RUN ]]; then
                echo "Would merge pi-dev-config defaults into $settingsPath"
                echo "Would apply declared pi-dev-config settings to $pidevPath"
            else
                mkdir -p "$settingsDir"
                if [[ ! -e "$settingsPath" ]]; then
                    printf '{}\n' > "$settingsPath"
                fi

                if ! ${pkgs.jq}/bin/jq -e 'type == "object"' "$settingsPath" >/dev/null; then
                    echo "Refusing to replace malformed pi settings: $settingsPath" >&2
                    exit 1
                fi

                tmp="$(${pkgs.coreutils}/bin/mktemp --tmpdir="$settingsDir" .settings.json.XXXXXX)"
                trap 'rm -f "$tmp"' EXIT
                ${pkgs.jq}/bin/jq \
                    --arg package "$packageSource" \
                    --argjson defaults ${lib.escapeShellArg settingsDefaultsJson} '
                    def packageSource:
                        if type == "string" then .
                        elif type == "object" then .source
                        else null
                        end;

                    $defaults + .
                    | .packages = (
                        (.packages // [])
                        | if type != "array" then [$package]
                          elif any(.[]; packageSource == $package) then .
                          else . + [$package]
                          end
                    )
                ' "$settingsPath" > "$tmp"
                chmod 0600 "$tmp"

                if cmp -s "$tmp" "$settingsPath"; then
                    rm -f "$tmp"
                else
                    mv -f "$tmp" "$settingsPath"
                fi
                trap - EXIT

                if [[ ! -e "$pidevPath" ]]; then
                    printf '{}\n' > "$pidevPath"
                fi

                if ! ${pkgs.jq}/bin/jq -e 'type == "object"' "$pidevPath" >/dev/null; then
                    echo "Refusing to replace malformed pi-dev-config settings: $pidevPath" >&2
                    exit 1
                fi

                tmp="$(${pkgs.coreutils}/bin/mktemp --tmpdir="$settingsDir" .pidev.json.XXXXXX)"
                trap 'rm -f "$tmp"' EXIT
                ${pkgs.jq}/bin/jq \
                    --argjson declared ${lib.escapeShellArg pidevSettingsJson} '
                    # Replace whole declared values instead of merging into them, so
                    # entries dropped from Nix also disappear from the mutable file.
                    # Keys pi-dev-config manages on its own are preserved.
                    . + $declared
                ' "$pidevPath" > "$tmp"
                chmod 0600 "$tmp"

                if cmp -s "$tmp" "$pidevPath"; then
                    rm -f "$tmp"
                else
                    mv -f "$tmp" "$pidevPath"
                fi
                trap - EXIT
            fi
        '';
    };
}
