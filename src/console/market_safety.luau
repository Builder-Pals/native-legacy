const WHITELISTED_CREATOR_ID = 32019485
const WHITELISTED_CREATOR_TYPE = Enum.CreatorType.Group

export type ProductCreator = {
	CreatorType: "User" | "Group",
	CreatorTargetId: number,
	Name: string,

	-- Present for some responses/accounts.
	HasVerifiedBadge: boolean?,
	Id: number?,
}

export type TimedOption = {
	-- Duration in seconds.
	Duration: number,
	Price: number,
}

export type AssetProductInfo = {
	-- Core asset metadata
	AssetId: number,
	AssetTypeId: number,
	Name: string,
	Description: string,
	IconImageAssetId: number,

	Creator: ProductCreator,

	-- Sale information
	IsForSale: boolean,
	IsPublicDomain: boolean,
	PriceInRobux: number?,
	PriceInTickets: number?,

	-- Limited/collectible information
	IsLimited: boolean,
	IsLimitedUnique: boolean,
	Remaining: number?,
	Sales: number?,

	-- Newer collectible fields
	CollectibleItemId: string?,
	CollectibleProductId: string?,
	CollectiblesItemDetails: {
		CollectibleLowestResalePrice: number?,
		CollectibleQuantityLimitPerUser: number?,
		TotalQuantity: number?,
		TotalRemaining: number?,
	}?,
	
	-- Assets that can be rented or purchased temporarily.
	TimedOptions: { TimedOption }?,
}

local market_safety = {}

function market_safety.is_game_allowed(info: AssetProductInfo): boolean
	if info.AssetTypeId == Enum.AssetType.Place.Value then
		return true	-- delegate gatekeeping to the web service
	end

	if info.Creator.CreatorTargetId ~= WHITELISTED_CREATOR_ID or info.Creator.CreatorType ~= WHITELISTED_CREATOR_TYPE.Name then
		return false
	end

	return true
end

return market_safety