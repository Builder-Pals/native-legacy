--[[
    Drops flags into the world when they're unequipped.
]]

local app = require("@layer/app")
local Composite = require("@layer/util/Composite")

local function with_character(character: Model): nil
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Flag" :: string) and child.Parent and child.Parent:IsA("Backpack") then
			task.defer(function()
				child.Parent = workspace
			end)
		end
	end)
	return nil
end

app.add_system("tool_joint_breaker", function(_)
	Composite.common.player_added:connect(function(player: Player)
		Composite.from(player.CharacterAdded):add(player.Character):connect(with_character)
		return nil
	end)
end, app.run_flags.SERVER)

return nil
