-- many thanks to the roblox set archive on GitHub created by pizzaboxer!
-- data converted using the jsonformatter xml-to-json site.

local sets_data = require("../sets_data")

type Set = sets_data.Set
type CollectionEntry = sets_data.CollectionEntry

local USER_ID_TO_NAME = {
    [18881829] = "happyhomeman",
    [11744447] = "usabilityman",
    [18881789] = "usabilityman2",
    [1] = "Roblox"
}

local function to_uid(x)
    return assert(tonumber(x), `invalid user id {x}`)
end

local sets_parser = {}

--- Returns an array of sets that belonged to a given user.
function sets_parser.get_user_sets(user_id: number | string): (boolean, { Set })
    local username = USER_ID_TO_NAME[to_uid(user_id)]

    if not username then
        return false, {}
    end

    local data = sets_data.users[username]

    if data then
        print(`returning {username}'s sets:`, data)
        return true, data
    else
        return false, {}
    end
end

--- Returns an array of Roblox's built in categories (used for the stamper tool).
function sets_parser.get_base_categories(): { Set }
    return sets_data.base
end

function sets_parser.get_collection(id: number | string): (boolean, { CollectionEntry })
    local string_id = tostring(id)
    local collection = sets_data.collections[string_id]

    if not collection then
        return false, {}
    end

    return true, collection
end

return sets_parser