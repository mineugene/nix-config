{
    yazi,
    yaziAlias,
    yaziTheme,
    yaziSettings,
    yaziInit,
    yaziZshInit,
    pkgs,
}:
assert yaziAlias == "y";
assert yazi.shellWrapperName == "y";
assert yazi.enable;
assert builtins.elem pkgs.lsd yazi.extraPackages;
assert builtins.elem pkgs.wl-clipboard yazi.extraPackages;
assert
    yazi.settings.plugin.prepend_previewers == [
        {
            url = "*/";
            run = "lsd-preview";
        }
    ];
assert yazi.theme == { };
assert yazi.flavors == { };
assert (builtins.length yazi.keymap.mgr.prepend_keymap) == 1;
assert (builtins.head yazi.keymap.mgr.prepend_keymap).run == "plugin smart-enter";
assert yazi.plugins ? smart-enter;
assert yazi.plugins ? lsd-preview;
assert yazi.plugins ? icon-pad;
assert yazi.plugins.icon-pad.setup;
# Alt-y widget: defined, bound in both viins and vicmd.
assert pkgs.lib.hasInfix "yazi-file-manager() {" yaziZshInit;
assert pkgs.lib.hasInfix "zle -N yazi-file-manager" yaziZshInit;
assert pkgs.lib.hasInfix "bindkey -M viins '^[y' yazi-file-manager" yaziZshInit;
assert pkgs.lib.hasInfix "bindkey -M vicmd '^[y' yazi-file-manager" yaziZshInit;
pkgs.runCommandLocal "yazi-check"
    {
        # Run yazi against the theme, init.lua, and plugins in a pty to
        # prove the pinned binary parses and renders them.
        nativeBuildInputs = [
            pkgs.util-linux
            pkgs.perl
            yazi.finalPackage
        ];
    }
    ''
        grep -F '${pkgs.lsd}/bin' ${yazi.finalPackage}/bin/yazi
        grep -F '${pkgs.wl-clipboard}/bin' ${yazi.finalPackage}/bin/yazi
        grep -F 'run = "lsd-preview"' ${yaziSettings}
        grep -F 'url = "*/"' ${yaziSettings}
        grep -F 'fg = "#a9b1d6", italic = true' ${yaziTheme}
        grep -F 'preview = { underline = false }' ${yaziTheme}
        grep -F '{ if = "link & dir", text = "", fg = "#9e9e9e" }' ${yaziTheme}
        grep -F '{ if = "link", text = "", fg = "#9e9e9e" }' ${yaziTheme}
        grep -F '{ if = "dir & hovered", text = "", fg = "#03a9f4" }' ${yaziTheme}
        grep -F '{ if = "dir", text = "", fg = "#03a9f4" }' ${yaziTheme}
        grep -F '{ if = "!dir", text = "", fg = "#ffffff" }' ${yaziTheme}
        grep -F 'border_symbol = "│"' ${yaziTheme}
        grep -F 'border_style  = { fg = "#565f89" }' ${yaziTheme}
        grep -F 'overall   = { fg = "#a9b1d6", bg = "reset" }' ${yaziTheme}
        test "$(grep -Ec '^perm_(type|read|write|exec|sep) += \{ fg = "#a9b1d6" \}$' ${yaziTheme})" = 5
        grep -F 'find_keyword  = { fg = "#16161e", bg = "#ff9e64", bold = true }' ${yaziTheme}
        grep -F '{ url = "*/", fg = "#7aa2f7" }' ${yaziTheme}

        # Every filetype rule must set url or mime.
        awk '
        /^\[filetype\]$/ { in_filetype = 1; next }
        /^\[/ { in_filetype = 0 }
        in_filetype && /^[[:space:]]*\{/ {
            if ($0 !~ /url[[:space:]]*=|mime[[:space:]]*=/) {
                print "filetype rule without url or mime: " $0 > "/dev/stderr"
                bad = 1
            }
        }
        END { exit bad }
        ' ${yaziTheme}

        mkdir -p "$TMPDIR/yazi/plugins" "$TMPDIR/yz/0-dir/hosts"
        cp ${yaziTheme} "$TMPDIR/yazi/theme.toml"
        cp ${yaziSettings} "$TMPDIR/yazi/yazi.toml"
        printf '%s\n' '${yaziInit}' > "$TMPDIR/yazi/init.lua"
        grep -F 'function Rail:redraw()' "$TMPDIR/yazi/init.lua"
        grep -F 'if self._id ~= "rail-right" then' "$TMPDIR/yazi/init.lua"
        grep -F 'ui.Bar(ui.Edge.LEFT):area(self._area):symbol(th.mgr.border_symbol):style(th.mgr.border_style)' "$TMPDIR/yazi/init.lua"
        grep -F 'local rendering_parent = false' "$TMPDIR/yazi/init.lua"
        grep -F 'if rendering_parent then' "$TMPDIR/yazi/init.lua"
        grep -F 'return style:fg("#565f89")' "$TMPDIR/yazi/init.lua"
        grep -F 'return icon and icon.text .. " " or ""' "$TMPDIR/yazi/init.lua"
        grep -F 'if rendering_parent and self._file.is_hovered then' "$TMPDIR/yazi/init.lua"
        grep -F 'return ui.Style():fg(bg):bg("#0c0e14"):reverse(true)' "$TMPDIR/yazi/init.lua"
        grep -F 'self._children[1]._area = self._children[1]._area:pad(ui.Pad(0, 1, 0, 0))' "$TMPDIR/yazi/init.lua"
        grep -F 'self._children[2]._area = self._children[2]._area:pad(ui.Pad(0, 1, 0, 0))' "$TMPDIR/yazi/init.lua"
        grep -F 'local overlay = ui.Style():bg("#0c0e14")' "$TMPDIR/yazi/init.lua"
        grep -F 'ui.Text(""):area(self._chunks[1]):style(overlay)' "$TMPDIR/yazi/init.lua"
        if grep -Fq 'ui.Text(""):area(self._chunks[3]):style(overlay)' "$TMPDIR/yazi/init.lua"; then
            echo "preview pane must use the terminal background" >&2
            exit 1
        fi
        grep -F 'local parent, current = path:match("^(.*[/])([^/]*)$")' "$TMPDIR/yazi/init.lua"
        grep -F 'ui.Span(parent):style(th.mgr.cwd:fg("#565f89"))' "$TMPDIR/yazi/init.lua"
        grep -F 'ui.Span(current):style(th.mgr.cwd)' "$TMPDIR/yazi/init.lua"
        grep -F 'local mode = tostring(self._tab.mode):upper()' "$TMPDIR/yazi/init.lua"
        grep -F 'ui.Span("  " .. mode .. "  "):style(style.main)' "$TMPDIR/yazi/init.lua"
        grep -F 'text = string.format("%d files selected", #selected)' "$TMPDIR/yazi/init.lua"
        grep -F 'if hovered and not hovered.cha.is_dir then' "$TMPDIR/yazi/init.lua"
        grep -F 'if not text then' "$TMPDIR/yazi/init.lua"
        grep -F 'percent = " Top "' "$TMPDIR/yazi/init.lua"
        grep -F 'percent = " Bottom "' "$TMPDIR/yazi/init.lua"
        grep -F 'string.format(" %d/%d ", math.min(cursor + 1, length), length)):style(style.alt)' "$TMPDIR/yazi/init.lua"
        grep -F '"--depth"' ${yazi.plugins.lsd-preview.package}/main.lua
        grep -F '"2"' ${yazi.plugins.lsd-preview.package}/main.lua
        grep -F 'if rt.mgr.show_hidden then' ${yazi.plugins.lsd-preview.package}/main.lua
        grep -F 'text:gsub("([\238\239][\128-\191][\128-\191]) ", "%1  ")' ${yazi.plugins.lsd-preview.package}/main.lua
        grep -F 'text:gsub("(\243[\176-\191][\128-\191][\128-\191]) ", "%1  ")' ${yazi.plugins.lsd-preview.package}/main.lua
        ln -s ${yazi.plugins.icon-pad.package} "$TMPDIR/yazi/plugins/icon-pad.yazi"
        ln -s ${yazi.plugins.lsd-preview.package} "$TMPDIR/yazi/plugins/lsd-preview.yazi"
        export YAZI_CONFIG_HOME="$TMPDIR/yazi"
        : > "$TMPDIR/yz/0-dir/hosts/tree-leaf"
        : > "$TMPDIR/yz/a.rs"
        : > "$TMPDIR/yz/b.md"
        cd "$TMPDIR/yz"
        parse_log="$TMPDIR/parse.log"
        status=0
        script -qec 'stty rows 40 cols 120; timeout 5 yazi' /dev/null >"$parse_log" 2>&1 || status=$?
        if grep -qiE 'failed|error|not found|preset settings' "$parse_log"; then
            cat "$parse_log" >&2
            exit 1
        fi
        if [ "$status" != 124 ] && [ "$status" != 0 ]; then
            cat "$parse_log" >&2
            exit 1
        fi
        grep -F 'tree-leaf' "$parse_log"
        perl -0777 -ne 'exit(/\xf3\xb0\x80\x82\x20(?:\e\[[0-9;]*m)*\x20/ ? 0 : 1)' "$parse_log" || {
            echo "lsd hosts icon padding missing" >&2
            exit 1
        }

        # icon-pad must widen the icon gap: an icon glyph followed by two
        # space cells (style escapes may sit between them).
        perl -0777 -ne 'exit(/(?:\xee|\xef)[\x80-\xbf]{2}\x20(?:\e\[[0-9;]*m)*\x20/ ? 0 : 1)' "$parse_log" || {
            echo "icon padding missing from rendered rows" >&2
            exit 1
        }

        touch "$out"
    ''
