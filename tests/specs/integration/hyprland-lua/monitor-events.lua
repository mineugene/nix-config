local callbacks = {}
local executed = {}
local applied = {}

package.preload["generated.monitor"] = function()
  return { { output = "one" }, { output = "two" } }
end
package.preload["generated.programs"] = function()
  return { monitor_topology = "/test/bin/monitor-topology" }
end
hl = {
  monitor = function(rule)
    table.insert(applied, rule.output)
  end,
  on = function(event, callback)
    callbacks[event] = callback
  end,
  exec_cmd = function(command)
    table.insert(executed, command)
  end,
}

dofile(os.getenv("MONITORS_LUA"))
assert(#applied == 2)
assert(applied[1] == "one")
assert(applied[2] == "two")
assert(type(callbacks["config.reloaded"]) == "function")
assert(type(callbacks["monitor.added"]) == "function")
callbacks["config.reloaded"]()
callbacks["monitor.added"]()
assert(executed[1] == "/test/bin/monitor-topology apply")
assert(executed[2] == "/test/bin/monitor-topology apply")
