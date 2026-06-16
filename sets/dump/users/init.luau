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
	["usabilityman"] = require("@self/usabilityman"),
	["usabilityman2"] = require("@self/usabilityman2"),
	["happyhomeman"] = require("@self/happyhomeman")
} :: { [string]: { Set } }