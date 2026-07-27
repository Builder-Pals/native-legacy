local catalog_types = require("./catalog_types")

local function get_game_thumbnail(id: number): string
	const W = 768
	const H = 432
	return `rbxthumb://type=GameThumbnail&id={id}&w={W}&h={H}`
end

const GAMES: { catalog_types.GameEntry } = {
	{
		name = "Build to Survive the Zombies",
        original_description = "",
        notes = "",
        place_id = 51955496,
        thumbnails = { get_game_thumbnail(51955496) },
		creator = {
			name = "DANGERTIM112",
			id = 15140266,
			type = "user",
		},
        best_version = { label = "2012" },
        versions = { { label = "2012" } }
	},

	{
		name = "DriveBlox Unlimited",
        original_description = "",
        notes = "",
        place_id = 52212574,
        thumbnails = { get_game_thumbnail(52212574) },
		creator = {
			name = "nfsboy",
			id = 16835181,
			type = "user",
		},
        best_version = { label = "2012" },
        versions = { { label = "2012" } },
	},

	{
		name = "Welcome to the Town of Robloxia",
        original_description = "",
        notes = "",
        place_id = 17312166208,
        thumbnails = { get_game_thumbnail(17312166208) },
		creator = {
			name = "1dev2",
			id = 693850,
			type = "user",
		},
		best_version = { label = "2010" },
        versions = { { label = "2010" } },
	},
}

return {
	all = GAMES,
}
