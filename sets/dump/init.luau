-- generated!
export type Set = {
	Name: string,
	CategoryId: string,
	Description: string,
	AssetSetId: string,
	CreatorName: string,
	ImageAsssetId: string,
	SetType: "private" | "public" | "base" | "user",
}

export type CollectionEntry = {
	Name: string,
	AssetId: string,
	AssetSetId: string,
	AssetVersionId: string,
	CreatorName: string,
	IsTrusted: boolean,
}

return {
	base = require("@self/base"),
	users = require("@self/users"),
	collections = require("@self/collections")
}
