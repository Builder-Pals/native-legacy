local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

local sets = require("@layer/sets")

-- simulated delay from calls to the LuaWebService
local API_CALL_DELAY = 0.1

app.add_patch(
	"insert_service_user_categories",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetUserCategories" },
		run = function(context, key)
			return function(_, user_id)
				if context.storage[user_id] == nil then
					context.storage[user_id] = true
					task.wait(API_CALL_DELAY)
				end

                local ok, user_sets = sets.parser.get_sets(user_id)
            
                if not ok then
                    warn(`sets for {user_id} have not been archived\n{debug.traceback()}`)
                    return {}
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

                print("OK - returning base categories",sets.parser.get_base_categories())
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
			return function(_self, category_id)
				if context.storage[category_id] == nil then
					context.storage[category_id] = true
					task.wait(API_CALL_DELAY)
				end

                local ok, collection = sets.parser.get_collection(category_id)
			
				if not ok then
					warn(`collection {category_id} has not been archived\n{debug.traceback()}`)
					return {}
				end

				print(`OK - returning collection for {category_id}`, collection)
				return collection
            end
		end,
	}
)

return nil
