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
    };
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
            pi-dev-config settings merged into its writable pidev.json file.
            Declared values override existing values.
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
                echo "Would merge declared pi-dev-config settings into $pidevPath"
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
                    # Recurse only into objects. jq multiplication concatenates arrays, which
                    # corrupts fixed-size values such as RGB triplets on each activation.
                    def merge($base; $override):
                        if ($base | type) == "object" and ($override | type) == "object" then
                            reduce ($override | keys_unsorted[]) as $key
                                ($base; .[$key] = merge(.[$key]; $override[$key]))
                        else $override
                        end;
                    merge(.; $declared)
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
