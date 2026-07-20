local MarketplaceService = game:GetService("MarketplaceService")

local deck = require("@layer/deck")
local web = require("@layer/web")
local market_safety = require("./market_safety")

export type GameSourceType =
	"PlaceId" -- tries to load games by their place id
	| "Archive" -- loads directly from their games by their marketplace id or archive id

local REJECTED_GAMES = {}

local function fetch_clone(source_asset_id: number | string): web.SandboxedGameResponse
	if REJECTED_GAMES[source_asset_id] then
		error(`game {source_asset_id} was already rejected by the server`)
	end

	return web.sandbox_place(source_asset_id)
end

local function set_store_creator_attributes(creator: number, type: string)
	workspace:SetAttribute("CreatorId", tonumber(creator))
	workspace:SetAttribute("CreatorType", type) -- User or Group
end

local function store_creator_from_id_async(place_id: number)
	local info: market_safety.AssetProductInfo = MarketplaceService:GetProductInfoAsync(place_id, Enum.InfoType.Asset)
	set_store_creator_attributes(info.Creator.CreatorTargetId, info.Creator.CreatorType)
end

const game_request_handler = {}

function game_request_handler.handle_async(asset_id: string): boolean
	local numerical_id
	print(`[load-game] trying to fetch a sandboxed copy... id={asset_id}`)

	if asset_id:sub(1, 4) == "nla_" then
		print("[load-game]\tid is an archive entry")
		local clone = fetch_clone(asset_id)

		if clone.source_place_id then
			store_creator_from_id_async(clone.source_place_id)
		end

		deck.unpacker.unpack_from_marketplace_async(clone.sandboxed_asset_id)
	else
		print("[load-game] - id is a place/game (?)")
		numerical_id = tonumber(asset_id)
		assert(numerical_id, "asset_id must be a number for regular assets")

		local info: market_safety.AssetProductInfo = MarketplaceService:GetProductInfoAsync(numerical_id, Enum.InfoType.Asset)

		if not market_safety.is_game_allowed(info) then
			warn(`[load-game] game id={asset_id} is not allowed`)
			return false
		end

		if info.AssetTypeId == Enum.AssetType.Place.Value then
			print("[load-game] - - id is a place!")
			local clone = fetch_clone(numerical_id)
			
			if clone.source_place_id then
				store_creator_from_id_async(clone.source_place_id)
			end

			deck.unpacker.unpack_from_marketplace_async(clone.sandboxed_asset_id)
		elseif info.AssetTypeId == Enum.AssetType.Model.Value then
			print("[load-game] - - id is a marketplace upload!")
			store_creator_from_id_async(numerical_id)
			deck.unpacker.unpack_from_marketplace_async(numerical_id)
		else
			warn(`[load-game] - game id={asset_id} is not a valid place or model`)
			return false
		end
	end

	return true
end

return game_request_handler
