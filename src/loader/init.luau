local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local player_relay = require("@layer/systems/default/Players/player_relay")
local booters = require("@layer/boot/booters")
local lighting_remapper = require("./systems/default/Lighting/lighting_remapper")
local make_joints = require("@layer/util/make_joints")
local packager = require("@layer/packager")
local nl_tags = require("@layer/nl_tags")

const MAX_JOINTS_PER_TICK = 900

local NEVER_CLEAN = {
	StarterPlayerScripts = true,
	StarterCharacterScripts = true,
	Chat = true,
}

local PLAYER_PROTECTED = {
	Backpack = true,
	StarterGear = true,
	PlayerGui = true,
	PlayerScripts = true,
}

-- taken straight from the ol' nostalgic layer :P
local function auto_assign_teams()
	local teams = Teams:GetTeams()
	local auto_assignable_teams: { Team } = {}

	for _, team in teams do
		if team.AutoAssignable then
			table.insert(auto_assignable_teams, team)
		end
	end

	if #auto_assignable_teams == 0 then
		return
	end

	local unassignedPlayers = Players:GetPlayers()
	local teamIndex = 0

	while #unassignedPlayers > 0 do
		local player = table.remove(unassignedPlayers, math.random(1, #unassignedPlayers)) :: Player
		teamIndex += 1
		player.Team = auto_assignable_teams[teamIndex % #auto_assignable_teams + 1]
	end
end

local function clean_player(player: Player)
	for _, child in player:GetChildren() do
		if child:HasTag(nl_tags.RELOAD_PROTECTION) == false and not PLAYER_PROTECTED[child.ClassName] then
			if not pcall(child.Destroy, child) then
				warn(`can't destroy {child:GetFullName()}`)
			end
		end
	end
end

local function clear_safely(parent: Instance)
	if parent:HasTag(nl_tags.RELOAD_PROTECTION) or NEVER_CLEAN[parent.ClassName] then
		return
	end

	for _, child in parent:GetChildren() do
		if child:IsA("Player") then
			clean_player(child)
			continue
		end

		if
			child:HasTag(nl_tags.RELOAD_PROTECTION)
			or child == workspace.Terrain
			or child == workspace.CurrentCamera
			or NEVER_CLEAN[child.ClassName]
		then
			continue
		end

		for _, child in child:GetDescendants() do
			if child:IsA("Sound") then
				child.PlayOnRemove = false
			end
		end

		if not pcall(child.Destroy, child) then
			warn(`can't destroy {child:GetFullName()}`)
		end
	end
end

local function freeze_workspace()
	local parts: { BasePart } = {}
	local dirty: { BasePart } = {}

	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") and not part:IsA("Terrain") then
			if not part.Anchored then
				part.Anchored = true
				part.LocalTransparencyModifier = 1
				table.insert(dirty, part)
			end

			table.insert(parts, part)
		end
	end

	return parts, dirty
end

local function thaw_workspace(dirty: { BasePart })
	for _, part in dirty do
		part.LocalTransparencyModifier = 0
		part.Anchored = false
	end
end

local loader = {}

function loader.load_game(package_instance: Instance)
	local package = packager.game_packager.read(package_instance)

	if not package.read_ok then
		warn(`[load-game] failed to load game '{package_instance}'! error: {package.error}\n{debug.traceback()}`)
		return
	end

	lighting_remapper.restore_defaults()
	player_relay.mask_players()

	for service_name in packager.game_packager.TARGET_SERVICES do
		local service = game:GetService(service_name)
		local ok, err = pcall(clear_safely, service)

		if not ok then
			print(`{service:GetFullName()} was not cleared: {err}`)
		end
	end
	
	booters.freeze()

	for _, service_info in package.services do
		print(`[load-game] unpacking {service_info.service}...`)
		packager.game_packager.unpack_service(service_info)
	end

	print("[load-game] unpack!")

	-- workspace:MakeJoints() used to be called on game load, but this was changed as part of the 'Part Surface Trilogy'. This could be controlled with a setting for a short period,
	-- which has since been hidden and will be overwritten by Roblox Studio.
	-- Devforum post: https://devforum.roblox.com/t/changes-to-surface-based-welds-and-part-property-setters/155477
	local parts, dirty = freeze_workspace()

	print("[load-game] frozen workspace")

	for index, part in parts do
		make_joints.make_joints(part)

		if index%MAX_JOINTS_PER_TICK == 0 then
			task.wait()
		end
	end

	print("[load-game] made joints")

	thaw_workspace(dirty)

	lighting_remapper.make_lighting_effects()
	lighting_remapper.run_remapper()

	booters.thaw()

	print("[load-game] success!")

	task.delay(1, function()
		print("[load-game] releasing players!")
		auto_assign_teams()
		player_relay.release_players()
	end)
end

--- loads a game based on its asset id - unpacking it into the DOM and replaying player join events.
function loader.load_game_from_marketplace_async(asset_id: number)
	local asset = AssetService:LoadAssetAsync(asset_id)
	local child = asset:GetChildren()[1]
	child.Sandboxed = false
	loader.load_game(child)
end

return loader
