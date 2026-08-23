local M = {}

local function fail(job, message)
	ya.preview_widget(job, ui.Text(message):area(job.area):wrap(ui.Wrap.YES))
end

function M:peek(job)
	local args = {
		"--tree",
		"--depth",
		"2",
		"--color",
		"always",
		"--icon",
		"always",
		"--group-directories-first",
	}
	if rt.mgr.show_hidden then
		args[#args + 1] = "--all"
	end
	args[#args + 1] = tostring(job.file.path)

	local child, err = Command("lsd")
		:arg(args)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
	if not child then
		return fail(job, "lsd: " .. err)
	end

	local limit = job.area.h
	local line, lines, errors = 0, {}, {}
	repeat
		local next, event = child:read_line()
		if event == 1 then
			errors[#errors + 1] = next
		elseif event ~= 0 then
			break
		end

		line = line + 1
		if line > job.skip then
			lines[#lines + 1] = next
		end
	until line >= job.skip + limit

	child:start_kill()
	if #errors > 0 then
		fail(job, table.concat(errors, ""))
	elseif job.skip > 0 and line < job.skip + limit then
		ya.emit("peek", { math.max(0, line - limit), only_if = job.file.url, upper_bound = true })
	else
		local text = table.concat(lines, ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
		text = text:gsub("([\238\239][\128-\191][\128-\191]) ", "%1  ")
		text = text:gsub("(\243[\176-\191][\128-\191][\128-\191]) ", "%1  ")
		ya.preview_widget(job, ui.Text.parse(text):area(job.area))
	end
end

function M:seek(job)
	require("code"):seek(job)
end

return M
