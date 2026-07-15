local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local network = require("@layer/network")
local patching = sandbox.patching

local TP_OFFSET = Vector3.new(0, 1.5, 0)

-- some scripts used to teleport the player by changing the cframe/position of the torso. doing this in modern Roblox will just detatch the
-- torso entirely.
--
-- restore old behaviour by changing model's pivot instead when the torso is teleported.
app.add_patch(
	"legacy_humanoid_torso_pivot",
	patching.setter_patch {
		classes = { "Part" },
		keys = { "Position", "CFrame" },
		run = function(context, key, value)
			local part = context.unsandboxed_object :: BasePart

			if part.Name == "Torso" and part.Parent and part.Parent:IsA("Model") then
				local humanoid = part.Parent:FindFirstChildOfClass("Humanoid")

				if humanoid then
					local cframe = if key == "Position"
						then CFrame.new(value, value + part.CFrame.LookVector)
						else value
					part.Parent:PivotTo(cframe + TP_OFFSET)
                    -- sink
                    return nil, nil
                end
			end

			return key, value
		end,
	}
)

app.add_system("legacy_humanoid", function(_)
	local function track_humanoid(humanoid: Humanoid)
		local function with_child(child: Instance)
			if not child:IsA("BasePart") then
				return
			end

			-- before the HumanoidRootPart existed, some scripts used to set the transparency of all children.
			-- this causes the always transparent HumanoidRootPart to become visible and causes ugly z-fighting.
			if child.Name == "HumanoidRootPart" then
				local transparency_watch = child:GetPropertyChangedSignal("Transparency"):Connect(function()
					child.Transparency = 1
				end)

				child:GetPropertyChangedSignal("Parent"):Once(function()
					transparency_watch:Disconnect()
				end)
			end
		end

		assert(humanoid.Parent)
		for _, child in humanoid.Parent:GetChildren() do
			with_child(child)
		end

		humanoid.Parent.ChildAdded:Connect(with_child)
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Humanoid") then
			track_humanoid(descendant)
		end
	end)

	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") then
			track_humanoid(descendant)
		end
	end
end)

return nil
