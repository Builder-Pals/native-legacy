--[[
    Breaks tool joints made to the map upon pickup.

    Fixes characters getting glued to tools attached to the world upon pickup.
    
    E.g: Flag stands and weapon pickups.
]]

local app = require("@layer/app")
local Composite = require("@layer/util/Composite")

local function with_character(character: Model): nil
	local function with_child(tool: Instance): nil
        if not tool:IsA("Tool") then
            return nil
        end

		local handle

		for _, child in tool:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Handle" then
				handle = child
				break
			end
		end

		if not handle then
			return nil
		end

		for _, joint: Weld in handle:GetJoints() do
			if joint:IsA("Weld") or joint:IsA("Snap") then
				if
					(joint.Part0 and not joint.Part0:IsDescendantOf(character))
					or (joint.Part1 and not joint.Part1:IsDescendantOf(character))
				then
					joint.Enabled = false
				end
			end
		end

        return nil
	end

    Composite.from(character.ChildAdded):add_array(character:GetChildren()):connect(with_child)
	return nil
end

app.add_system("tool_joint_breaker", function(_)
	Composite.common.player_added:connect(function(player: Player)
		Composite.from(player.CharacterAdded):add(player.Character):connect(with_character)
		return nil
	end)
end, app.run_context.SERVER)

return nil
