local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return function() end
end

local network = require("@layer/network")
local loader = require("@layer/loader")
local web = require("@layer/web")
local remotes = network.remotes
local server = network.remotes.reliable.server

local REJECTED_GAMES = {}
local debounce = false

local function fetch_clone(source_asset_id: number | string): web.SandboxedGameResponse
	if REJECTED_GAMES[source_asset_id] then
		error(`game {source_asset_id} was already rejected by the server`)
	end

	return web.sandbox_place(source_asset_id)
end

local function store_creator_async(game_id: number)
	local product_info = MarketplaceService:GetProductInfoAsync(game_id, Enum.InfoType.Asset)
	workspace:SetAttribute("CreatorId", tonumber(product_info.Creator.CreatorTargetId))
	workspace:SetAttribute("CreatorType", product_info.Creator.CreatorType) -- User or Group
end

local function request(asset_id: number | string, is_uncopylocked_game: boolean): boolean
	if is_uncopylocked_game then
		if typeof(asset_id) == "number" and not loader.is_game_allowed(asset_id) then
			warn(`[load-game] game {asset_id} is not allowed`)
			return false
		end

		print(`trying to fetch a sandboxed copy... id={asset_id}`)
		local game_data = fetch_clone(asset_id)
		print(`fetched sandboxed clone of place id={asset_id}: {game_data}`)

		if game_data.source_place_id then
			local ok, err = pcall(store_creator_async, game_data.source_place_id)

			if not ok then
				warn(`failed to store creator for {game_data.source_place_id}: {err}\n{debug.traceback()}`)
			end
		end

		loader.load_game_from_marketplace_async(game_data.sandboxed_asset_id)
		return true
	else
		assert(type(asset_id) == "number", "asset_id must be a number for regular assets")

		if not loader.is_game_allowed(asset_id) then
			warn(`[load-game] game {asset_id} is not allowed`)
			return false
		end

		loader.load_game_from_marketplace_async(asset_id)
		return true
	end
end

return function()
	server.subscribe({}, remotes.ids.reliable.console.load_place, function(_player, asset_id, is_uncopylocked_game)
		if debounce then
			return
		end

		assert(type(asset_id) == "number" or type(asset_id) == "string", "asset_id must be a number or string")
		assert(type(is_uncopylocked_game) == "boolean", "is_uncopylocked_game must be a boolean")

		print(`loading {asset_id}`)

		debounce = true

		local ok, result = pcall(request, asset_id, is_uncopylocked_game)

		if not ok then
			warn(`failed to load game {asset_id}: {result}\n{debug.traceback()}`)
		end
		
		debounce = false
	end)
end
