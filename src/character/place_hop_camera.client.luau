if not workspace:HasTag("place_hopping") then
    return
end

workspace:RemoveTag("place_hopping")

local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local humanoid = script.Parent:WaitForChild("Humanoid", 20)

if not humanoid then
	warn("Failed to find Humanoid")
	return
end

assert(humanoid:IsA("Humanoid"))

-- unhide any core ui that was hidden by the previous game
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

humanoid.CameraOffset = Vector3.new(3, 5, 0)

TweenService
	:Create(
		humanoid,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CameraOffset = Vector3.zero }
	)
	:Play()
