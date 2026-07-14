local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local player_relay = require("@layer/systems/default/Players/player_relay")
local packager = require("./packager")
local nl_constants = require("@layer/nl_constants")

local NEVER_CLEAN = {
	StarterPlayerScripts = true,
	StarterCharacterScripts = true,
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
		if child:HasTag(nl_constants.RELOAD_PROTECTION) == false and not PLAYER_PROTECTED[child.ClassName] then
			if not pcall(child.Destroy, child) then
				warn(`can't destroy {child:GetFullName()}`)
			end
		end
	end
end

local function clear_safely(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("Player") then
			clean_player(child)
			continue
		end

		if
			child:HasTag(nl_constants.RELOAD_PROTECTION)
			or child == workspace.Terrain
			or child == workspace.CurrentCamera
			or NEVER_CLEAN[child.ClassName]
		then
			continue
		end

		if not pcall(child.Destroy, child) then
			warn(`can't destroy {child:GetFullName()}`)
		end
	end
end

local loader = {}

function loader.load_game(package_instance: Instance)
	local package = packager.game_packager.read(package_instance)
	
	if not package.read_ok then
		warn(`[load-game] failed to load game '{package_instance}'! error: {package.error}\n{debug.traceback()}`)
		return
	end

	player_relay.mask_players()

	clear_safely(Players)

	for _, service_info in package.services do
		clear_safely(service_info.service)
		print(`[load-game] unpacking {service_info.service}...`)
		packager.game_packager.unpack_service(service_info)
	end

	print("[load-game] success!")

	task.delay(1, function()
		print("[load-game] releasing players!")
		auto_assign_teams()
		player_relay.release_players()
	end)
end

--- loads a game based on its asset id - unpacking it into the DOM and replaying player join events.
function loader.load_game_from_id(asset_id: number)
	local asset = AssetService:LoadAssetAsync(asset_id)
	local children = asset:GetChildren()[1]
	children.Sandboxed = false
	loader.load_game(children)
end

return loader
