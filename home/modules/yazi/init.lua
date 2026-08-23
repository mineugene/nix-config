function Rail:redraw()
	if self._id ~= "rail-right" then
		return {}
	end

	return {
		ui.Bar(ui.Edge.LEFT):area(self._area):symbol(th.mgr.border_symbol):style(th.mgr.border_style),
	}
end

local rendering_parent = false
local parent_redraw = Parent.redraw

function Parent:redraw()
	rendering_parent = true
	local elements = parent_redraw(self)
	rendering_parent = false
	return elements
end

local entity_style = Entity.style
local entity_icon = Entity.icon

function Entity:style()
	local style = entity_style(self)
	if rendering_parent then
		return style:fg("#565f89")
	end
	return style
end

function Entity:icon()
	if rendering_parent then
		local icon = th.icon:match(self._file, { hovered = self._file.is_hovered })
		return icon and icon.text .. " " or ""
	end
	return entity_icon(self)
end

local entity_style_rev = Entity.style_rev

function Entity:style_rev()
	if rendering_parent and self._file.is_hovered then
		local bg = self:style():bg(true)
		if bg then
			return ui.Style():fg(bg):bg("#0c0e14"):reverse(true)
		end
	end

	return entity_style_rev(self)
end

local tab_build = Tab.build

function Tab:build()
	tab_build(self)
	self._children[1]._area = self._children[1]._area:pad(ui.Pad(0, 1, 0, 0))
	self._children[2]._area = self._children[2]._area:pad(ui.Pad(0, 1, 0, 0))
	local overlay = ui.Style():bg("#0c0e14")
	self._base = {
		ui.Text(""):area(self._chunks[1]):style(overlay),
	}
end

function Header:cwd()
	local max = self._area.w - self._right_width
	if max <= 0 then
		return ""
	end

	local path = ya.readable_path(tostring(self._current.cwd))
	local parent, current = path:match("^(.*[/])([^/]*)$")
	if not parent or current == "" then
		return ui.Span(ui.truncate(path .. self:flags(), { max = max, rtl = true })):style(th.mgr.cwd)
	end

	current = ui.truncate(current .. self:flags(), { max = max, rtl = true })
	parent = ui.truncate(parent, { max = math.max(0, max - ui.width(current)), rtl = true })

	return ui.Line {
		ui.Span(parent):style(th.mgr.cwd:fg("#565f89")),
		ui.Span(current):style(th.mgr.cwd),
	}
end

function Status:mode()
	local mode = tostring(self._tab.mode):upper()
	local style = self:style()

	return ui.Line {
		ui.Span(th.status.sep_left.open):fg(style.main:bg()):bg(App.bg()),
		ui.Span("  " .. mode .. "  "):style(style.main),
		ui.Span(th.status.sep_left.close):fg(style.main:bg()):bg(style.alt:bg()),
	}
end

function Status:length()
	local style = self:style()
	local selected = self._tab.selected
	local text

	if #selected > 0 then
		local size, files = 0, 0
		for _, file in pairs(selected) do
			if not file.cha.is_dir then
				size = size + file.cha.len
				files = files + 1
			end
		end

		text = string.format("%d files selected", #selected)
		if files > 0 then
			text = text .. "  " .. ya.readable_size(size)
		end
	else
		local hovered = self._current.hovered
		if hovered and not hovered.cha.is_dir then
			text = ya.readable_size(hovered.cha.len)
		end
	end

	if not text then
		return ""
	end

	return ui.Line {
		ui.Span(" " .. text .. " "):style(style.alt),
		ui.Span(th.status.sep_left.close):fg(style.alt:bg()),
	}
end

function Status:percent()
	local percent = 0
	local cursor = self._current.cursor
	local length = #self._current.files
	if cursor ~= 0 and length ~= 0 then
		percent = math.floor((cursor + 1) * 100 / length)
	end

	if percent == 0 then
		percent = " Top "
	elseif percent == 100 then
		percent = " Bottom "
	else
		percent = string.format(" %2d%% ", percent)
	end

	local style = self:style()
	return ui.Line {
		ui.Span(" " .. th.status.sep_right.open):fg(style.alt:bg()),
		ui.Span(percent):style(style.alt),
	}
end

function Status:position()
	local cursor = self._current.cursor
	local length = #self._current.files
	local style = self:style()

	return ui.Line {
		ui.Span(string.format(" %d/%d ", math.min(cursor + 1, length), length)):style(style.alt),
		ui.Span(th.status.sep_right.close):fg(style.alt:bg()):bg(App.bg()),
	}
end
