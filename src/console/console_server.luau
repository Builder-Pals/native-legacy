local network = require("@layer/network")
local loader = require("@layer/loader")
local remotes = network.remotes
local server = network.remotes.reliable.server

return function()
	server.subscribe({}, remotes.ids.reliable.console.load_place, function(_player, asset_id)
		assert(typeof(asset_id) == "number", "asset_id must be a number")
        print(`loading {asset_id}`)
        loader.load_game_from_id(asset_id)
	end)
end
