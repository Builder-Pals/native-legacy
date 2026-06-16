local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

local sets = require("@layer/sets")

app.add_patch(
	"insert_service_user_categories",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetUserCategories" },
		run = function(context, key)
			return function(_, user_id: number)
                local ok, user_sets = sets.parser.get_sets(user_id)
            
                if not ok then
                    warn(`sets for {user_id} have not been archived`)
                    return {}
                end

                print(`OK - returning sets for {user_id}`)
                return user_sets
            end
		end,
	}
)

app.add_patch(
	"insert_service_base_categories",
	patching.getter_patch {
		classes = { "InsertService" },
		keys = { "GetUserCategories" },
		run = function(_context, _key)
			return function(_self)
                print("OK - returning base categories",sets.parser.get_base_categories())
                return sets.parser.get_base_categories()
            end
		end,
	}
)

return nil
