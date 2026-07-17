local RunService = game:GetService("RunService")

if RunService:IsClient() then return function() end end

local network = require("@layer/network")
local loader = require("@layer/loader")
local web = require("@layer/web")
local remotes = network.remotes
local server = network.remotes.reliable.server

local REJECTED_GAMES = {}
local debounce = false

local function fetch_clone(source_asset_id: number): number
	if REJECTED_GAMES[source_asset_id] then
		error(`game {source_asset_id} was already rejected by the server`)
	end

	return web.sandbox_place(source_asset_id)
end

return function()
	server.subscribe({}, remotes.ids.reliable.console.load_place, function(_player, asset_id, is_uncopylocked_game)
		if debounce then
			return
		end

		assert(typeof(asset_id) == "number", "asset_id must be a number")
		print(`loading {asset_id}`)

		debounce = true

		if is_uncopylocked_game then
			xpcall(function()
				print(`trying to fetch a sandboxed copy... id={asset_id}`)
				local sandboxed_asset_id = fetch_clone(asset_id)
				print(`fetched sandboxed clone of place id={asset_id}: {sandboxed_asset_id}`)
				loader.load_game_from_marketplace(sandboxed_asset_id)
			end, function(err)
				warn(`failed to load game {asset_id}: {err}\n{debug.traceback()}`)
				REJECTED_GAMES[asset_id] = true
			end)
		else
			xpcall(function()
				loader.load_game_from_marketplace(asset_id)
			end, function(err)
				warn(`failed to load game {asset_id}: {err}\n{debug.traceback()}`)
			end)
		end

		debounce = false
	end)
end
