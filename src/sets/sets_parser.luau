-- many thanks to the roblox set archive on GitHub created by pizzaboxer!
-- data converted using the jsonformatter xml-to-json site.

local DATA_MAP = {
    happyhomeman = require("./data/users/happyhomeman"),
    usabilityman = require("./data/users/usabilityman"),
    usabilityman2 = require("./data/users/usabilityman2"),
}

export type Set = {
    Name: string,
    CategoryId: string,
    Description: string,
    AssetSetId: string,
    CreatorName: string,
    ImageAsssetId: string,
    SetType: "private" | "public",
}

local function parse(data: typeof(DATA_MAP.happyhomeman))
    local sets = {}
    
    for _, set in data.List.Value do
        local output = {}
        
        for _, entry in set.Table.Entry do
            output[entry.Key] = entry.Value
        end

        table.insert(sets, output :: Set)
    end

    return sets
end

local USER_TO_SETS = {
    happyhomeman = parse(DATA_MAP.happyhomeman),
    usabilityman = parse(DATA_MAP.usabilityman),
    usabilityman2 = parse(DATA_MAP.usabilityman2), 
}

local USER_ID_TO_SETS = {
    [18881829] = USER_TO_SETS.happyhomeman,
    [11744447] = USER_TO_SETS.usabilityman,
    [18881789] = USER_TO_SETS.usabilityman2,
}

local sets_parser = {}

--- Returns an array of sets that belonged to a given user.
function sets_parser.get_sets(user_id: number): (boolean, { Set })
    local result = USER_ID_TO_SETS[user_id]

    if not result then
        return false, {}
    end

    return true, USER_ID_TO_SETS[user_id]
end

--- Returns an array of Roblox's built in categories (used for the stamper tool).
function sets_parser.get_base_categories(): { Set }
    local categories = {}

    for _, sets in USER_ID_TO_SETS do
        for _, set in sets do
            table.insert(categories, set)
        end
    end

    return categories
end

return sets_parser