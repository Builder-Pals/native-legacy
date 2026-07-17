local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

const LOCAL_API_URL = "http://api.localhost:8080"
const WEB_API_URL = "https://api.fizzyhex.design"
const API_KEY = HttpService:GetSecret("NL_WEB_SERVICE_KEY")

local web = {}

local function fetch_clone(api_url: string, source_asset_id: number): number
	local url = string.format("%s/v1/sandbox_game/%d", api_url, source_asset_id)
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
function web.sandbox_place(place_id: number): number
	if RunService:IsStudio() then
		local ok, sandboxed_asset_id = pcall(fetch_clone, LOCAL_API_URL, place_id)

		if ok then
			return sandboxed_asset_id
		end

		warn(
			`Local sandbox service failed for game {place_id}; falling back to the web service: {sandboxed_asset_id}`
		)
	end

	return fetch_clone(WEB_API_URL, place_id)
end

return web
