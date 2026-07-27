local plz = require("@layer/plz")
local prefabs = require("./prefabs")

--[[
	future: create a floating dropdown that sits at the top of the game wheel,
	allowing the user to switch between all games, favourites and recently played.

	the dropdown is opaque at the top and when hovered, becoming transparent when the user scrolls with
	outlined text for the currently selected category.
]]

export type DropdownProps = {
	
}

local function DynamicDropdown(pen: plz.Pen, props: DropdownProps)
	local frame = pen:node(prefabs.Frame)
	frame.Name = "dropdown"
	frame.Size = UDim2.fromOffset(250, 50)

    return frame
end

return DynamicDropdown