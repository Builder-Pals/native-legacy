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
	require("@self/My Models"),
	require("@self/My Decals"),
	require("@self/XD Decal Set"),
	require("@self/XD Skate Park Set"),
	require("@self/Gameplay"),
	require("@self/Models"),
	require("@self/Parts")
} :: { Set }