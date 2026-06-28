local app = require("@layer/app")
local Composite = require("@layer/util/Composite")

local function with_character(character: Model)
	local function with_tool(tool: Tool)
		local handle

		for _, child in tool:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Handle" then
				handle = child
				break
			end
		end

		if not handle then
			return
		end

		for _, joint: Weld in handle:GetJoints() do
			if joint:IsA("Weld") or joint:IsA("Snap" :: string) then
				if
					(joint.Part0 and not joint.Part0:IsDescendantOf(tool))
					or (joint.Part1 and not joint.Part1:IsDescendantOf(tool))
				then
					joint.Enabled = false
				end
			end
		end
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			with_tool(child)
		end
	end)

	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			with_tool(child)
		end
	end

	return nil
end

app.add_system("tool_joint_breaker", function(_)
	Composite.common.player_added:connect(function(player: Player)
		Composite.new(player.CharacterAdded, player.Character, with_character)
		return nil
	end)
end, app.run_context.SERVER)

return nil
