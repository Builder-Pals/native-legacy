local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

local sets = require("@layer/sets")

-- these patches repair the deprecated sets API with a local catalog of well-known sets.
-- it also restores client-side LoadAsset access, wihch was removed for security reasons many years ago.
--
-- note: roblox along the way seems to have privated a lot of assets that were used in sets,
-- so they will fail to load. could work around by re-uploading copies of common assets and mapping
-- them across in the future.

-- simulated delay from calls to the LuaWebService (Sets API)
local API_CALL_DELAY = 0.1

local CUTOFF_YEAR_UNIX = DateTime.fromUniversalTime(2019).UnixTimestamp

local remote: RemoteFunction

if RunService:IsClient() and RunService:IsRunning() then
	remote = script:WaitForChild("RemoteFunction") :: RemoteFunction
else
	remote = Instance.new("RemoteFunction")
	remote.Parent = script
end

app.add_system("insert_service_net", function(_)
	local blocked = {}

	remote.OnServerInvoke = function(_player, asset_id)
		if blocked[asset_id] then
			error("Request was blocked for security reasons")
		end

		local result = AssetService:LoadAssetAsync(asset_id)
		result.Sandboxed = false

		local asset_info = game:GetService("MarketplaceService"):GetProductInfoAsync(asset_id, Enum.InfoType.Asset)

		if not asset_info.IsPublicDomain then
			blocked[asset_id] = true
			error("Private asset was blocked")
			return result
		end

		local creation_date = DateTime.fromIsoDate(asset_info.Created)

		if creation_date.UnixTimestamp > CUTOFF_YEAR_UNIX then
			blocked[asset_id] = true
			error("Asset was created too recently to use")
		end

		if asset_info.CreatorId == 40763226 then
			blocked[asset_id] = true
			error("Request was blocked for security reasons")
		end

		result.Parent = ReplicatedStorage
		return result
	end
end, RunService:IsServer())

app.add_patch(
	"insert_service_load_asset",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "LoadAsset", "LoadAssetVersion", "loadAsset", "loadAssetVersion" },
		run = function(context)
			return function(_, asset_id)
				if context.storage[asset_id] then
					assert(context.storage[asset_id], "Request asset was not found")
					return context.storage[asset_id]
				end

				print("requesting asset", asset_id)

				local result = remote:InvokeServer(asset_id)
				context.storage[asset_id] = result:Clone()

				assert(result, "Request asset was not found")
				return result
			end
		end,
	}
)

app.add_patch(
	"insert_service_user_categories",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetUserCategories" },
		run = function(context, _)
			return function(_, user_id): { [string]: any }?
				if context.storage[user_id] == nil then
					context.storage[user_id] = true
					task.wait(API_CALL_DELAY)
				end

				local ok, user_sets = sets.parser.get_user_sets(user_id)

				if not ok then
					warn(`sets for {user_id} have not been archived\n{debug.traceback()}`)
					return nil -- the web service api used to return nil too
				end

				print(`OK - returning sets for {user_id}`, user_sets)
				return user_sets
			end
		end,
	}
)

app.add_patch(
	"insert_service_base_categories",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetBaseCategories" },
		run = function(context, _key)
			return function(_self)
				if context.storage.base_categories == nil then
					context.storage.base_categories = true
					task.wait(API_CALL_DELAY)
				end

				return sets.parser.get_base_categories()
			end
		end,
	}
)

app.add_patch(
	"insert_service_get_collection",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetCollection" },
		run = function(context, _key)
			return function(_self, category_id): { [string]: any }?
				if context.storage[category_id] == nil then
					context.storage[category_id] = true
					task.wait(API_CALL_DELAY)
				end

				local ok, collection = sets.parser.get_collection(category_id)

				if not ok then
					warn(`collection {category_id} has not been archived\n{debug.traceback()}`)
					return nil -- the web service api used to return nil too
				end

				print(`OK - returning collection for {category_id}`, collection)
				return collection
			end
		end,
	}
)

return nil
