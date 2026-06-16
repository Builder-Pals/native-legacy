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

return {
	require("@self/Parts"),
	require("@self/Models"),
	require("@self/Gameplay")
} :: { Set }