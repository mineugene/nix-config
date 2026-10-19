lutils = require("linking-utils")
cutils = require("common-utils")
Log.open_topic("openxlr-capture"):info("capture target restore ready")

SimpleEventHook({
	name = "openxlr/follow-default-capture-target",
	before = "linking/find-defined-target",
	interests = {
		EventInterest({
			Constraint({ "event.type", "=", "select-target" }),
		}),
	},
	execute = function(event)
		local _, object_manager, si, properties = lutils:unwrap_select_target_event(event)
		local metadata = cutils.get_default_metadata_object()
		local target = metadata and properties["node.id"] and metadata:find(properties["node.id"], "target.object")
		if target == "-1" then
			properties["node.dont-fallback"] = "false"
			event:set_data("target", lutils.findDefaultLinkable(si))
			return
		end
		properties["node.dont-fallback"] = target and "true" or "false"
		if not target then
			return
		end
		local found = false
		for linkable in object_manager:iterate({ type = "SiLinkable" }) do
			local candidate = linkable.properties
			if candidate["node.name"] == target or candidate["object.serial"] == tostring(target) then
				found = true
				break
			end
		end
		if not found then
			event:stop_processing()
		end
	end,
}):register()

capture_state = State("stream-properties")

function capture_form_key(properties)
	if properties["media.role"] == "Notification" then
		return string.format("%s:%s", properties["media.class"]:gsub("^Stream/", ""), "media.role:Notification")
	end
	local keys = { "application.id", "application.name", "media.name", "node.name" }
	for _, key in ipairs(keys) do
		local value = properties[key]
		if value then
			return string.format("%s:%s:%s", properties["media.class"]:gsub("^Stream/", ""), key, value)
		end
	end
	return nil
end

SimpleEventHook({
	name = "openxlr/restore-unavailable-capture-target",
	before = "node/restore-stream",
	interests = {
		EventInterest({
			Constraint({ "event.type", "=", "node-added" }),
			Constraint({ "media.class", "=", "Stream/Input/Audio" }),
		}),
	},
	execute = function(event)
		local node = event:get_subject()
		local key = capture_form_key(node.properties)
		local capture_state_table = capture_state:load()
		local raw = key and capture_state_table[key]
		if not raw then
			return
		end
		local stored = Json.Raw(raw)
		local values = stored and stored:is_object() and stored:parse()
		local target = values and values.target
		if not target then
			return
		end
		local metadata = event:get_source():call("get-object-manager", "metadata"):lookup({
			Constraint({ "metadata.name", "=", "default" }),
		})
		if metadata and not metadata:find(node["bound-id"], "target.object") then
			metadata:set(node["bound-id"], "target.object", "Spa:Id", target)
		end
	end,
}):register()
