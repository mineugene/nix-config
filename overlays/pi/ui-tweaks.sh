#!/usr/bin/env bash
# requires Bash.
# Calls stdenv's substituteInPlace for fail-loud, line-drift-proof edits.
# Single quotes intentionally preserve ${...} and backtick source text.
# shellcheck disable=SC2016

substituteInPlace packages/coding-agent/src/extensions/codemode/renderer.ts \
    --replace-fail 'return theme.fg("warning", "…");' 'return theme.fg("warning", "\u{f141}");' \
    --replace-fail 'return theme.fg("success", "✓");' 'return theme.fg("success", "\u{f058}");' \
    --replace-fail 'return theme.fg("error", "✗");' 'return theme.fg("error", "\u{f057}");'

substituteInPlace packages/coding-agent/src/extensions/llama/ui.ts \
    --replace-fail 'const prefix = index === this.selectedIndex ? "→ " : "  ";' \
        'const prefix = index === this.selectedIndex ? "\u{f432}  " : "   ";'

substituteInPlace packages/coding-agent/src/extensions/mcp/index.ts \
    --replace-fail '`${exposure === current ? "✓ " : "  "}${exposure}`' \
        '`${exposure === current ? "\u{f058}  " : "   "}${exposure}`'

substituteInPlace packages/coding-agent/src/modes/interactive/components/extension-selector.ts \
    --replace-fail '? theme.fg("accent", "→ ") + theme.fg("accent", this.options[i])' \
        '? theme.fg("accent", "\u{f432}  ") + theme.fg("accent", this.options[i])' \
    --replace-fail ': `  ${theme.fg("text", this.options[i])}`;' \
        ': `   ${theme.fg("text", this.options[i])}`;'

substituteInPlace packages/coding-agent/src/modes/interactive/components/first-time-setup.ts \
    --replace-fail 'const prefix = isSelected ? theme.fg("accent", "→ ") : "  ";' \
        'const prefix = isSelected ? theme.fg("accent", "\u{f432}  ") : "   ";'

substituteInPlace packages/coding-agent/src/modes/interactive/components/model-selector.ts \
    --replace-fail 'const cursor = isSelected ? theme.fg("accent", "→ ") : "  ";' \
        'const cursor = isSelected ? theme.fg("accent", "\u{f432}  ") : "   ";' \
    --replace-fail 'const currentMarker = isCurrent ? theme.fg("accent", "✓ ") : "  ";' \
        'const currentMarker = isCurrent ? theme.fg("accent", "\u{f058}  ") : "   ";'

substituteInPlace packages/coding-agent/src/modes/interactive/components/oauth-selector.ts \
    --replace-fail 'return theme.fg("success", " ✓ configured");' \
        'return theme.fg("success", " \u{f058}  configured");' \
    --replace-fail 'return theme.fg("success", ` ✓ ${source}`);' \
        'return theme.fg("success", ` \u{f058}  ${source}`);'

substituteInPlace packages/coding-agent/src/modes/interactive/components/scoped-models-selector.ts \
    --replace-fail 'const prefix = isSelected ? theme.fg("accent", "→ ") : "  ";' \
        'const prefix = isSelected ? theme.fg("accent", "\u{f432}  ") : "   ";' \
    --replace-fail 'const status = item.model && item.enabled ? theme.fg("accent", "✓ ") : "  ";' \
        'const status = item.model && item.enabled ? theme.fg("accent", "\u{f058}  ") : "   ";'

substituteInPlace packages/coding-agent/src/modes/interactive/components/settings-selector.ts \
    --replace-fail 'label: `${name === currentTheme ? "✓ " : "  "}${name}`,' \
        'label: `${name === currentTheme ? "\u{f058}  " : "   "}${name}`,' \
    --replace-fail 'label: `${level === activeLevel ? "✓ " : "  "}${level}`,' \
        'label: `${level === activeLevel ? "\u{f058}  " : "   "}${level}`,' 

substituteInPlace packages/coding-agent/src/modes/interactive/components/thinking-selector.ts \
    --replace-fail 'label: `${level === currentLevel ? "✓ " : "  "}${level}`,' \
        'label: `${level === currentLevel ? "\u{f058}  " : "   "}${level}`,' 

substituteInPlace packages/coding-agent/src/modes/interactive/components/trust-selector.ts \
    --replace-fail 'const currentMarker = isCurrent ? theme.fg("accent", "✓ ") : "  ";' \
        'const currentMarker = isCurrent ? theme.fg("accent", "\u{f058}  ") : "   ";' \
    --replace-fail 'const prefix = isSelected ? theme.fg("accent", "→ ") : "  ";' \
        'const prefix = isSelected ? theme.fg("accent", "\u{f432}  ") : "   ";'

substituteInPlace packages/coding-agent/src/modes/interactive/interactive-mode.ts \
    --replace-fail '${theme.fg("success", "✓")} ${this.formatPathWithSource' \
        '${theme.fg("success", "\u{f058}")}  ${this.formatPathWithSource' \
    --replace-fail '${theme.fg("warning", "✗")} ${this.formatPathWithSource' \
        '${theme.fg("warning", "\u{f057}")}  ${this.formatPathWithSource' \
    --replace-fail 'const hintText = theme.fg("dim", `↳ ${dequeueHint} to edit all queued messages`);' \
        'const hintText = theme.fg("dim", `\u{f17a9}  ${dequeueHint} to edit all queued messages`);' \
    --replace-fail 'theme.fg("accent", "✓ New session started")' \
        'theme.fg("accent", "\u{f058}  New session started")' \
    --replace-fail 'theme.fg("accent", "✓ Debug log written")' \
        'theme.fg("accent", "\u{f058}  Debug log written")'

substituteInPlace packages/coding-agent/src/modes/interactive/theme/theme.ts \
    --replace-fail 'cursor: theme.fg("accent", "→ "),' 'cursor: theme.fg("accent", "\u{f432}  "),'

substituteInPlace packages/tui/src/components/select-list.ts \
    --replace-fail 'const prefix = isSelected ? "→ " : "  ";' \
        'const prefix = isSelected ? "\u{f432}  " : "   ";'

substituteInPlace packages/tui/src/components/settings-list.ts \
    --replace-fail 'const prefix = isSelected ? this.theme.cursor : "  ";' \
        'const prefix = isSelected ? this.theme.cursor : "   ";'

substituteInPlace packages/tui/src/components/loader.ts \
    --replace-fail 'const DEFAULT_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];' \
        $'const DEFAULT_FRAMES = [\n\t"⠀⠀⠀⠀",\n\t"⡇⠀⠀⠀",\n\t"⣿⠀⠀⠀",\n\t"⢸⡇⠀⠀",\n\t"⠀⣿⠀⠀",\n\t"⠀⢸⡇⠀",\n\t"⠀⠀⣿⠀",\n\t"⠀⠀⢸⡇",\n\t"⠀⠀⠀⣿",\n\t"⠀⠀⠀⢸",\n];' \
    --replace-fail 'const DEFAULT_INTERVAL_MS = 80;' 'const DEFAULT_INTERVAL_MS = 70;'

substituteInPlace packages/coding-agent/src/modes/interactive/components/status-indicator.ts \
    --replace-fail 'export type StatusIndicatorKind = "working" | "retry" | "compaction" | "branchSummary";' \
        $'export type StatusIndicatorKind = "working" | "retry" | "compaction" | "branchSummary";\n\nconst LINE_FRAMES = [\n\t"⠀⠀⠀⠀",\n\t"⠁⠁⠁⠁",\n\t"⠂⠂⠂⠂",\n\t"⠄⠄⠄⠄",\n\t"⡀⡀⡀⡀",\n\t"⠀⠀⠀⠀",\n\t"⡀⡀⡀⡀",\n\t"⠄⠄⠄⠄",\n\t"⠂⠂⠂⠂",\n\t"⠁⠁⠁⠁",\n];\nconst REVERSED_PULSE_FRAMES = ["⡁⠀⢈", "⣏⠀⣹", "⢾⣉⡷", "⠰⣿⠆", "⠀⠶⠀", "⠀⠀⠀"];' \
    --replace-fail $'\t\t\tretryMessage(Math.ceil(delayMs / 1000)),\n\t\t);' \
        $'\t\t\tretryMessage(Math.ceil(delayMs / 1000)),\n\t\t\t{\n\t\t\t\tframes: LINE_FRAMES.map((frame) => theme.fg("warning", frame)),\n\t\t\t\tintervalMs: 70,\n\t\t\t},\n\t\t);' \
    --replace-fail $'\t\t\tcolorFn ?? ((text) => theme.fg("muted", text)),\n\t\t\tlabel,\n\t\t);' \
        $'\t\t\tcolorFn ?? ((text) => theme.fg("muted", text)),\n\t\t\tlabel,\n\t\t\t{\n\t\t\t\tframes: REVERSED_PULSE_FRAMES.map((frame) => theme.fg("accent", frame)),\n\t\t\t\tintervalMs: 180,\n\t\t\t},\n\t\t);'

substituteInPlace packages/coding-agent/src/modes/interactive/components/assistant-message.ts \
    --replace-fail $'\t\tconst hasVisibleContent = message.content.some(\n\t\t\t(c) => (c.type === "text" && c.text.trim()) || (c.type === "thinking" && c.thinking.trim()),\n\t\t);' \
        $'\t\tconst thinkingSuppressed = this.hideThinkingBlock && !this.hiddenThinkingLabel;\n\t\tconst hasVisibleContent = message.content.some(\n\t\t\t(c) =>\n\t\t\t\t(c.type === "text" && c.text.trim()) ||\n\t\t\t\t(c.type === "thinking" && c.thinking.trim() && !thinkingSuppressed),\n\t\t);' \
    --replace-fail $'\t\t\t\tconst hidden = this.thinkingVisibilityOverrides.get(runIndex) ?? this.hideThinkingBlock;' \
        $'\t\t\t\tconst hidden = this.thinkingVisibilityOverrides.get(runIndex) ?? this.hideThinkingBlock;\n\t\t\t\tif (hidden && !this.hiddenThinkingLabel) {\n\t\t\t\t\tcontinue;\n\t\t\t\t}'
