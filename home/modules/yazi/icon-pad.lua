-- Yazi hardcodes one space between each file icon and its name; widen the
-- gap by one column in the parent, current, and preview panes.
local function setup()
    Entity:children_add(function()
        return " "
    end, 2500)
end

return { setup = setup }
