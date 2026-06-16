local net = require("@std/net")
local xml = require("@self/polyfill/xml")
local json = require("@std/json")
local fs = require("@std/fs")
local task = require("@std/task")

local TARGET_USERS = {
	11744447, -- usabilityman
	18881789, -- usabilityman2
	18881829, -- happyhomeman
}

export type Set = {
	Name: string,
	CategoryId: string,
	Description: string,
	AssetSetId: string,
	CreatorName: string,
	ImageAsssetId: string,
	SetType: "private" | "public" | "base",
}

local USER_REQUEST = "https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?nsets=20&type=user&userid="

local function print_t(t, depth)
	depth = depth or 0

	for k, v in pairs(t) do
		print(string.rep("  ", depth) .. tostring(k) .. ": " .. tostring(v))
		if type(v) == "table" then
			print_t(v, depth + 1)
		end
	end
end

--- Parses the key/value pairs from set XML
local function parse_entry(x): Set
	local output = {}

	assert(x.tag == "Value")
	assert(x.children[1].tag == "Table")
	assert(x.children[1].children)

	local set_key_value_pairs = x.children[1].children

	for _, kvp in set_key_value_pairs do
		local key = kvp.children[1]
		local value = kvp.children[2]

		assert(key.tag == "Key", key.tag or "<no tag>")
		assert(value.tag == "Value", value.tag or "<no tag>")

		output[key.children] = value.children
	end

	return output :: Set
end

fs.createDirectory("dump/users", { makeParents = true })
fs.createDirectory("dump/base", { makeParents = true })
fs.createDirectory("dump/raw", { makeParents = true })

local function dump_raw(path: string, xml: string, json: string)
    do
        local file = fs.open(`{path}.xml`, "w")
        fs.write(file, xml)
		fs.close(file)
    end

    do
        local file = fs.open(`{path}.json`, "w")
        fs.write(file, json)
		fs.close(file)
    end
end

local function dump_base_sets()
    local result = net.request("https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?nsets=10&type=base", {
		method = "GET",
	})

    assert(result.ok, `Failed to fetch base sets: {result.status} {result.body}`)

    local xml_result = xml.parse(buffer.fromstring(result.body))
    assert(xml_result, `Failed to parse XML for base sets: {result.body}`)

    local children = xml_result.children :: { [any]: any }
    dump_raw("dump/raw/base_sets", result.body, json.serialize(children, true))

	for _, xml_set in xml_result.children do
		local set = parse_entry(xml_set)
		
		-- dump
		do
			local file = fs.open(`dump/base/{set.Name}.json`, "w")
			fs.write(file, json.serialize(set, true))
			fs.close(file)
		end
	end
end

-- dump base sets
dump_base_sets()

-- dump user sets
for _, uid in TARGET_USERS do
	local result = net.request(`{USER_REQUEST}{uid}`, {
		method = "GET",
	})

	if not result.ok then
		error(`Failed to fetch user sets for UID {uid}: {result.status} {result.body}`)
	end

	local xml_result = xml.parse(buffer.fromstring(result.body))
	assert(xml_result, `Failed to parse XML for UID {uid}: {result.body}`)

	local children = xml_result.children :: { [any]: any }

	-- dump sets
	for index, xml_set in children do
		local set = parse_entry(xml_set)
		print("set:", json.serialize(set, true))

        -- dump set
		do
            if index == 1 then
                fs.createDirectory(`dump/users/{set.CreatorName}`, { makeParents = true })
            end

			local file = fs.open(`dump/users/{set.CreatorName}/{set.Name}.json`, "w")
			fs.write(file, json.serialize(set, true))
			fs.close(file)
		end
	end

	-- dont wreck the servers!
	task.wait(0.5)
end

print("done!")