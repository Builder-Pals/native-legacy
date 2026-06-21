local player_relay = require("./systems/default/Players/player_relay")
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

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

local nl_constants = require("@layer/nl_constants")

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
		if child:HasTag(nl_constants.RELOAD_PROTECTION) == false and not PLAYER_PROTECTED[child.Name] then
			if not pcall(child.Destroy, child) then
				warn(`can't destroy {child:GetFullName()}`)
			end
		end
	end
end

local function clean(parent: Instance)
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

function loader.load_game(package: Instance)
	local dom_container = package:FindFirstChild("DataModel") or package:FindFirstChild("startPlace")

	if not dom_container then
		local place_config = package:FindFirstChild("NewNostalgicPlaceConfig")
		assert(place_config, "package missing DataModel container and NewNostalgicPlaceConfig")
		local dataModelPackage = place_config:FindFirstChild("DataModelPackage")
		assert(dataModelPackage, "package missing DataModel container and NewNostalgicPlaceConfig/DataModelPackage")
		local services = dataModelPackage:FindFirstChild("Services")
		assert(services, "package missing DataModel container and NewNostalgicPlaceConfig/DataModelPackage/Services")
		dom_container = services
		print("using compatibility system")
	end

	assert(dom_container, "package missing DataModel container")

	player_relay.mask_players()

	for _, child in dom_container:GetChildren() do
		local service = game:GetService(child.Name)
		clean(service)

		for _, instance in child:GetChildren() do
			instance.Parent = service
		end
	end

	task.delay(1, function()
		print("releasing players!")
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
