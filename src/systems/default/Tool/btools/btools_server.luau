--!nonstrict
local app = require("@layer/app")
local nl_tags = require("@layer/nl_tags")
local make_joints = require("../../../../util/make_joints")
-------------------------------------------------------------------------------------------------------------------------
-- @CloneTrooper1019, 2017-2018 <3
-- ClassicBuildTools.lua
-- A FilteringEnabled port of Roblox's classic build tools.
-------------------------------------------------------------------------------------------------------------------------
-- Initial Declarations
-------------------------------------------------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return nil
end

local DraggerService = Instance.new("Folder")
DraggerService:AddTag("nl_relaod_protection")
DraggerService.Name = "DraggerService"
DraggerService.Parent = ReplicatedStorage
DraggerService:AddTag(nl_tags.RELOAD_PROTECTION)

local DraggerGateway = Instance.new("RemoteFunction")
DraggerGateway.Name = "DraggerGateway"
DraggerGateway.Parent = DraggerService

local SubmitUpdate = Instance.new("RemoteEvent")
SubmitUpdate.Name = "SubmitUpdate"
SubmitUpdate.Parent = DraggerService

local DECLARED_BUILD_TOOLS = {
	GameTool = true,
	Clone = true,
	Hammer = true,
}

-------------------------------------------------------------------------------------------------------------------------
-- Server Gateway Logic
-------------------------------------------------------------------------------------------------------------------------
--[[

~ HOW THIS WORKS ~

	* In order to drag a part, a player must request permission from the server to drag the part.
	* If any of the following conditions are true, the request will be rejected:
		* The part is Locked.
		* The player is dragging another part, and hasn't released it.
		* The part is being dragged by another player.
		* The player does not have a character.
		* The player does not have the tool corresponding to the action equipped.
	* If the player is granted permission...
		* A key is generated representing the current drag action, and this key is passed back to the player.
		* This key marks both the part being dragged, and the player.
		* The player can submit the key and a CFrame to the SubmitUpdate event to move the part.
		* The player MUST release the key in order to drag another part, or their request is rejected.
		* Key is automatically released if the part is destroyed, or the player leaves the game.
--]]

local activeKeys = {}
local deleteDebounce = {}

local partToKey = {}
local playerToKey = {}

local function assertClass(obj, class)
	assert(obj)
	assert(typeof(obj) == "Instance")
	assert(obj:IsA(class))
end

local function canGiveKey(player, part)
	if part.Locked then
		return false
	end

	if playerToKey[player] then
		return false
	end

	if partToKey[part] then
		return false
	end

	return true
end

local function claimAssembly(player, part)
	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(player)
	end
end

local function removePartKey(key)
	local data = activeKeys[key]

	if data then
		-- Clear this first so cleanup cannot re-enter through a tool ancestry callback.
		activeKeys[key] = nil

		local player = data.Player
		local part = data.Part
		local toolConnection = data.ToolConnection

		if toolConnection then
			toolConnection:Disconnect()
		end

		if player then
			playerToKey[player] = nil
		end

		if part then
			-- Connect this part to a nearby surface
			make_joints.make_joints(part)

			part.Anchored = data.Anchored
			claimAssembly(player, part)

			partToKey[part] = nil
		end
	end
end

local function removeToolKey(tool)
	for key, data in activeKeys do
		if data.Tool == tool then
			removePartKey(key)
			return
		end
	end
end

local function find_tool(char)
	for _, child in char:GetChildren() do
		if child:IsA("Accessory") and child:HasTag("nl_pseudo_tool") then
			return child
		end
	end

	return nil
end

local function playerIsUsingTool(player, toolName)
	local char = player.Character

	if char then
		local tool = find_tool(char)
		if tool and CollectionService:HasTag(tool, toolName) then
			return true, tool
		end
	end

	return false
end

local function swingBuildTool(player)
	local char = player.Character
	if char then
		local tool = find_tool(char)
		if tool and CollectionService:HasTag(tool, "BuildTool") then
			local toolAnim = Instance.new("StringValue")
			toolAnim.Name = "toolanim"
			toolAnim.Value = "Slash"
			toolAnim.Parent = tool
		end
	end
end

local function onSubmitUpdate(player, key, cframe)
	local keyData = activeKeys[key]
	if keyData then
		local owner = keyData.Player
		if owner == player then
			local part = keyData.Part
			if part and part:IsDescendantOf(workspace) then
				part.CFrame = cframe
			end
		end
	end
end

local function onCharacterAdded(player)
	-- reset the key on character spawn. helps against cases where the character is destroyed but a dragger is active.
	local key = playerToKey[player]
	if key then
		removePartKey(key)
	end
end

local function onPlayerRemoved(player)
	local key = playerToKey[player]
	if key then
		removePartKey(key)
	end
end

app.add_system("btools_server", function(_)
	SubmitUpdate.OnServerEvent:Connect(onSubmitUpdate)

	----------------------------------------------------------------------------------------------------------------------------
	-- Tool Initialization
	----------------------------------------------------------------------------------------------------------------------------

	local draggerScript = script.Parent:WaitForChild("DraggerScript")

	for toolName in pairs(DECLARED_BUILD_TOOLS) do
		local BuildToolAdded = CollectionService:GetInstanceAddedSignal(toolName)
		local BuildToolRemoved = CollectionService:GetInstanceRemovedSignal(toolName)

		local function onBuildToolAdded(tool)
			if tool:IsA("Accessory") and not CollectionService:HasTag(tool, "BuildTool") then
				tool.Name = toolName

				local dragger = draggerScript:Clone()
				dragger.Parent = tool
				dragger.Disabled = false

				CollectionService:AddTag(tool, "BuildTool")
			end
		end

		local function onBuildToolRemoved(tool)
			if tool:IsA("Accessory") and CollectionService:HasTag(tool, "BuildTool") then
				removeToolKey(tool)

				CollectionService:RemoveTag(tool, toolName)
				CollectionService:RemoveTag(tool, "BuildTool")

				local char = tool.Parent
				if char and char:IsA("Model") then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:UnequipTools()
					end
				end

				if tool:FindFirstChild("DraggerScript") then
					tool.DraggerScript:Destroy()
				end
			end
		end

		for _, buildTool in pairs(CollectionService:GetTagged(toolName)) do
			onBuildToolAdded(buildTool)
		end

		BuildToolAdded:Connect(onBuildToolAdded)
		BuildToolRemoved:Connect(onBuildToolRemoved)
	end

	function DraggerGateway.OnServerInvoke(player, request, ...)
		if request == "GetKey" then
			local part, asClone = ...
			assertClass(part, "BasePart")
			local clonedPart

			-- Reaching GetKey means the client is no longer operating its previous drag.
			-- Recover here if that drag's cleanup was interrupted by the LocalScript or tool being destroyed.
			local previousKey = playerToKey[player]
			if previousKey then
				removePartKey(previousKey)
			end

			-- Reject before cloning so a failed request cannot leave a descendant in Workspace.
			if part.Locked or not player.Character then
				return false
			end

			local toolName = if asClone then "Clone" else "GameTool"
			local isUsingTool, equippedTool = playerIsUsingTool(player, toolName)
			if not isUsingTool then
				return false
			end

			if asClone then
				clonedPart = part:Clone()
				clonedPart:BreakJoints()
				clonedPart.Parent = workspace

				local copySound = Instance.new("Sound")
				copySound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
				copySound.Parent = clonedPart
				copySound.Archivable = false
				copySound:Play()

				part = clonedPart
			end

			if canGiveKey(player, part) then
				local char = player.Character
				if char then
					local key = HttpService:GenerateGUID(false)
					playerToKey[player] = key
					partToKey[part] = key

					claimAssembly(player, part)
					swingBuildTool(player)

					local anchored = part.Anchored
					part:BreakJoints()
					part.Anchored = true

					local keyData = {
						Player = player,
						Part = part,
						Anchored = anchored,
						Tool = equippedTool,
					}
					activeKeys[key] = keyData

					keyData.ToolConnection = equippedTool.AncestryChanged:Connect(function()
						if equippedTool.Parent ~= player.Character then
							removePartKey(key)
						end
					end)

					return true, key, part
				end
			end

			if clonedPart then
				clonedPart:Destroy()
			end

			return false
		elseif request == "ClearKey" then
			local key = ...

			if not key then
				key = playerToKey[player]
			end

			if key then
				local data = activeKeys[key]
				if data then
					local owner = data.Player
					if player == owner then
						removePartKey(key)
					end
				end
			end
		elseif request == "RequestDelete" then
			if not deleteDebounce[player] and playerIsUsingTool(player, "Hammer") then
				local part = ...
				assertClass(part, "BasePart")

				if canGiveKey(player, part) then
					local e = Instance.new("Explosion")
					e.BlastPressure = 0
					e.Position = part.Position
					e.Parent = workspace

					local s = Instance.new("Sound")
					s.PlayOnRemove = true
					s.SoundId = "rbxasset://sounds/collide.wav"
					s.Volume = 1
					s.Parent = part

					swingBuildTool(player)
					claimAssembly(player, part)

					part:Destroy()
				end

				task.wait(0.1)
				deleteDebounce[player] = false
			end
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoved)

	----------------------------------------------------------------------------------------------------------------------------
	-- Garbage Collection
	----------------------------------------------------------------------------------------------------------------------------

	task.spawn(function()
		while task.wait(1) do
			for part, key in pairs(partToKey) do
				if not part:IsDescendantOf(workspace) then
					removePartKey(key)
				end
			end
		end
	end)
end, RunService:IsServer())

return nil
