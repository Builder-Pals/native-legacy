local plz = require("@layer/plz")
local GameCard = require("./GameCard")

local function get_game_thumbnail(id: number): string
	const W = 768
	const H = 432
	return `rbxthumb://type=GameThumbnail&id={id}&w={W}&h={H}`
end

const GAME = {
	title = "Build to Survive the Zombies",
	author = "DANGERTIM112",
	thumbnail = get_game_thumbnail(51955496),
	description = [[
*MELTING ZOMBIES ARE GONE IN VERSION 28.3*
Build with your StamperTool to survive the zombies.
VIP:http://www.roblox.com/Zombie-VIP-Shirt-item?id=67718932
ADMINS: DANGERTIM112, DANGERTIM113, sarac08, lalala654321, callmex, jntterminatorxx, tripodpoprica5000. They won't give you admin unless i aprove you to get admin.
        ]],
}

return function(parent: Frame)
	local pen = plz:pen()
	local state

	local function render(delta_time)
		local props = GAME

		local ui
		ui, state = GameCard(pen, GAME, state)
		ui.Position = UDim2.fromOffset(16, 16)
		ui.Size = UDim2.fromOffset(500, 500)
		ui.Parent = parent
	end

	return plz.loop(pen, render)
end
