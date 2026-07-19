local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local web = {}

const LOCAL_API_URL = "http://api.localhost:8080"
const WEB_API_URL = "https://api.fizzyhex.design"
const IS_SERVER = RunService:IsServer()

const API_KEY = if IS_SERVER then HttpService:GetSecret("NL_WEB_SERVICE_KEY") else ""

export type SandboxedGameResponse = {
	source_place_id: number?,
	sandboxed_asset_id: number,
}

local function fetch_game_clone(api_url: string, source_asset_id: number | string): SandboxedGameResponse
	local url = string.format(`{api_url}/v1/sandbox_game/{source_asset_id}`, api_url, source_asset_id)
	local response = HttpService:RequestAsync {
		Url = url,
		Method = "GET",
		Headers = {
			["x-api-key"] = API_KEY,
		},
	}

	print("web response:", response)

    local body = response.Body or ""

	if response.StatusCode ~= 200 then
		error(string.format("Sandbox service returned HTTP %d: %s", response.StatusCode, body))
	end

	local json = HttpService:JSONDecode(body)
	assert(typeof(json.sandboxed_asset_id) == "number", "Response did not contain a sandboxed asset ID")

	assert(tonumber(json.sandboxed_asset_id), `expected a number, got {json.sandboxed_asset_id}`)
	assert(json.source_place_id == nil or tonumber(json.source_place_id), `expected a number, got {json.source_place_id}`)

	return {
		source_place_id = json.source_place_id,
		sandboxed_asset_id = json.sandboxed_asset_id,
	}
end

local function fetch_asset_clone(api_url: string, source_asset_id: number | string): number
	local url = string.format(`{api_url}/v1/sandbox/{source_asset_id}`, api_url, source_asset_id)
	local response = HttpService:RequestAsync {
		Url = url,
		Method = "GET",
		Headers = {
			["x-api-key"] = API_KEY,
		},
	}

	print("web response:", response)

	local body = response.Body or ""

	if response.StatusCode ~= 200 then
		error(string.format("Sandbox service returned HTTP %d: %s", response.StatusCode, body))
	end

	local json = HttpService:JSONDecode(body)
	assert(typeof(json.sandboxed_asset_id) == "number", "Response did not contain a sandboxed asset ID")

	return assert(tonumber(json.sandboxed_asset_id), `expected a number, got {json.sandboxed_asset_id}`)
end

--[[
    Fetches a sandboxed copy of a game from the web service. If running in Studio, it will first attempt to fetch from the local sandbox service.
    @param place_id The asset ID of the place to sandbox.
    @return The marketplace asset ID of the sandboxed copy of the place.
]]
function web.sandbox_place(place_id: number | string): SandboxedGameResponse
	assert(IS_SERVER, "web apis cannot be used on the client")

	if RunService:IsStudio() then
		local ok, sandboxed_asset = pcall(fetch_game_clone, LOCAL_API_URL, place_id)

		if ok then
			return sandboxed_asset
		end

		warn(
			`Local sandbox service failed for game {place_id}; falling back to the web service: {sandboxed_asset}`
		)
	end

	return fetch_game_clone(WEB_API_URL, place_id)
end

--[[
	Fetches a sandboxed copy of an asset from the web service. If running in Studio, it will first attempt to fetch from the local sandbox service.
	@param asset_id The asset ID of the asset to sandbox.
	@return The marketplace asset ID of the sandboxed copy of the asset.
]]
function web.sandbox_asset(asset_id: number): number
	assert(IS_SERVER, "web apis cannot be used on the client")

	if RunService:IsStudio() then
		local ok, sandboxed_asset_id = pcall(fetch_asset_clone, LOCAL_API_URL, asset_id)

		if ok then
			return sandboxed_asset_id
		end

		warn(
			`Local sandbox service failed for asset {asset_id}; falling back to the web service: {sandboxed_asset_id}`
		)
	end

	return fetch_asset_clone(WEB_API_URL, asset_id)
end

return web
