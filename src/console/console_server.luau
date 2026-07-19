local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return function() end
end

local network = require("@layer/network")
local game_request_handler = require("./game_request_handler")
local remotes = network.remotes
local server = network.remotes.reliable.server

local debounce = false

return function()
	server.subscribe({}, remotes.ids.reliable.console.load_place, function(_player, asset_id)
		if debounce then
			return
		end

		assert(type(asset_id) == "string", "asset_id must be a string")
		print(`loading {asset_id}`)

		debounce = true

		local ok, result = pcall(game_request_handler.handle_async, asset_id)

		if not ok then
			warn(`failed to load game {asset_id}: {result}\n{debug.traceback()}`)
		end

		debounce = false
	end)
end
