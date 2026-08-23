local monitor = require("generated.monitor")
local programs = require("generated.programs")

if type(monitor) == "table" then
  for _, rule in ipairs(monitor) do
    hl.monitor(rule)
  end
end

local restore_topology = function()
  hl.exec_cmd(programs.monitor_topology .. " apply")
end

hl.on("config.reloaded", restore_topology)
hl.on("monitor.added", restore_topology)
