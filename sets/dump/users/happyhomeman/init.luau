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
	require("@self/Experimental"),
	require("@self/High Scalability"),
	require("@self/Vehicles"),
	require("@self/Gear"),
	require("@self/Gameplay")
} :: { Set }