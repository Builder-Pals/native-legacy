local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

if RunService:IsClient() then return function() end end

const API_URL = if RunService:IsStudio() then "http://api.localhost:8080" else "https://api.fizzyhex.design"
const API_KEY = HttpService:GetSecret("NL_WEB_SERVICE_KEY")

local network = require("@layer/network")
local loader = require("@layer/loader")
local remotes = network.remotes
local server = network.remotes.reliable.server

local REJECTED_GAMES = {}
local debounce = false

local function fetch_uncopylocked_clone(source_asset_id: number): number
	if REJECTED_GAMES[source_asset_id] then
		error(`game {source_asset_id} is uncopylocked but has been rejected by the server`)
	end

	local url = string.format("%s/v1/sandbox_game/%d", API_URL, source_asset_id)

	local ok, response = pcall(function()
		return HttpService:RequestAsync {
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-key"] = API_KEY,
			},
		}
	end)

	if not ok then
		error(`failed to load game: id={source_asset_id} {response}`)
	end

	print("web response:", response)
	local body = HttpService:JSONDecode(response.Body)

	if response.StatusCode == 200 then
		assert(typeof(body.sandboxed_asset_id) == "number", "Response did not contain a sandboxed asset ID")

		return body.sandboxed_asset_id
	end

	error(string.format("Sandbox service returned HTTP %d: %s", response.StatusCode, response.Body))
end

-- TODO: proper rate limiting - could def pull out a helper from an old project.

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
				local sandboxed_asset_id = fetch_uncopylocked_clone(asset_id)
				print(`fetched sandboxed clone of place id={asset_id}: {sandboxed_asset_id}`)
				loader.load_game_from_id(sandboxed_asset_id)
			end, function(err)
				warn(`failed to load uncopylocked game {asset_id}: {err}\n{debug.traceback()}`)
				REJECTED_GAMES[asset_id] = true
			end)
		else
			xpcall(function()
				loader.load_game_from_id(asset_id)
			end, function(err)
				warn(`failed to load game {asset_id}: {err}\n{debug.traceback()}`)
			end)
		end

		debounce = false
	end)
end
