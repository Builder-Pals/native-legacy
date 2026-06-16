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
	require("@self/Basic Building"),
	require("@self/Advanced Building"),
	require("@self/House Kit"),
	require("@self/House Interior Kit"),
	require("@self/Landscape"),
	require("@self/Castle Kit"),
	require("@self/Castle Interior Kit"),
	require("@self/Space Kit"),
	require("@self/Fun Machines"),
	require("@self/Deadly Machines")
} :: { Set }