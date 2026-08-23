local monitor = require("generated.monitor")
local programs = require("generated.programs")

if type(monitor) == "table" then
  hl.monitor(monitor)
end

local restore_topology = function()
  hl.exec_cmd(programs.monitor_topology .. " apply")
end

local focus_primary = function()
  hl.exec_cmd(programs.monitor_topology .. " focus-primary")
end

hl.on("config.reloaded", restore_topology)
hl.on("monitor.added", restore_topology)
hl.on("config.props_refreshed", focus_primary)
