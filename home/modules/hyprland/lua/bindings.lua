local programs = require("generated.programs")

local screenshot_command = programs.grim .. ' -g "$('
    .. programs.slurp
    .. ')" - | '
    .. programs.wl_copy
    .. " --type image/png"

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(programs.terminal))
hl.bind("SUPER + B", hl.dsp.exec_cmd(programs.browser))
hl.bind("SUPER + D", hl.dsp.exec_cmd(programs.ui_launcher))
hl.bind("SUPER + L", hl.dsp.exec_cmd(programs.lock))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + M", hl.dsp.exec_cmd(programs.ui_power))
hl.bind("SUPER + V", hl.dsp.exec_cmd(programs.ui_clipboard))
hl.bind("Print", hl.dsp.exec_cmd(screenshot_command))

hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

for workspace = 1, 9 do
    hl.bind("SUPER + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(programs.wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {
    locked = true,
    repeating = true,
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(programs.wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
    locked = true,
    repeating = true,
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(programs.wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    locked = true,
})
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(programs.wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), {
    locked = true,
})

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
