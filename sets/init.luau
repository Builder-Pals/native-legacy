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
	SetType: "private" | "public" | "base" | "user",
}

export type CollectionEntry = {
	Name: string,
	AssetId: string,
	AssetSetId: string,
	AssetVersionId: string,
	CreatorName: string,
	IsTrusted: boolean,
}

local SET_TYPE = [[
export type Set = {
	Name: string,
	CategoryId: string,
	Description: string,
	AssetSetId: string,
	CreatorName: string,
	ImageAsssetId: string,
	SetType: "private" | "public" | "base" | "user",
}
]]

local COLLECTION_ENTRY_TYPE = [[
export type CollectionEntry = {
	Name: string,
	AssetId: string,
	AssetSetId: string,
	AssetVersionId: string,
	CreatorName: string,
	IsTrusted: boolean,
}
]]

local USER_REQUEST = "https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?nsets=20&type=user&userid="
local COLLECTION_REQUEST = "https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?sid="

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
fs.createDirectory("dump/collections", { makeParents = true })
fs.createDirectory("dump_raw/", { makeParents = true })

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

type CanSerDes = boolean | string | { [boolean | string]: any }
local function to_luau(value: CanSerDes): string
	if typeof(value) == "boolean" then
		return tostring(value)
	elseif typeof(value) == "string" then
		return `"{value:gsub('"', '\\"')}"` -- escape quotes
	elseif typeof(value) == "table" then
		local parts = {}

		for key, value in pairs(value) do
			table.insert(parts, `{key} = {to_luau(value)}`)
		end

		return `{ { table.concat(parts, ", ") }}`
	end

	error(`Unsupported type: {typeof(value)}`)
end

local function dump_base_sets()
	local result = net.request("https://sets.pizzaboxer.xyz/Game/Tools/InsertAsset.ashx?nsets=10&type=base", {
		method = "GET",
	})

	assert(result.ok, `Failed to fetch base sets: {result.status} {result.body}`)

	local xml_result = xml.parse(buffer.fromstring(result.body))
	assert(xml_result, `Failed to parse XML for base sets: {result.body}`)

	local children = xml_result.children :: { [any]: any }
	dump_raw("dump_raw/base_sets", result.body, json.serialize(children, true))

	local mapping = {}

	for _, xml_set in xml_result.children do
		local set = parse_entry(xml_set)

		-- dump
		do
			local file = fs.open(`dump/base/{set.Name}.json`, "w")
			fs.write(file, json.serialize(set, true))
			fs.close(file)

			table.insert(mapping, `\trequire("@self/{set.Name}")`)
		end
	end

	-- make typed init.luau file
	do
		local file = fs.open("dump/base/init.luau", "w")
		fs.write(file, `-- generated!\n`)

		fs.write(file, `{SET_TYPE}\n`)

		fs.write(file, "return {\n")
		local entries = table.concat(mapping, ",\n")
		fs.write(file, entries)
		fs.write(file, "\n} :: { Set }")

		fs.close(file)
	end
end

local function dump_collection(id: string)
	local result = net.request(`{COLLECTION_REQUEST}{id}`, {
		method = "GET",
	})

	assert(result.ok, `Failed to fetch collection {id}: {result.status} {result.body}`)

	local xml_result = xml.parse(buffer.fromstring(result.body))
	assert(xml_result, `Failed to parse XML for collection {id}: {result.body}`)

	local children = xml_result.children :: { [any]: any }
	dump_raw(`dump_raw/collection_{id}`, result.body, json.serialize(children, true))

	local all_entries = {}

	for _, xml_entry in children do
		local entry = parse_entry(xml_entry) :: CollectionEntry
		print(json.serialize(entry, true))
		table.insert(all_entries, json.serialize(entry, true))
	end

	-- make json dump
	do
		local file = fs.open(`dump/collections/{id}.json`, "w")
		fs.write(file, json.serialize(all_entries, true))
		fs.close(file)
	end
end

local function dump_user_sets()
	local collection_mapping = {}
	local user_mapping = {}

	-- dump user sets
	for _, user_id in TARGET_USERS do		
		local result = net.request(`{USER_REQUEST}{user_id}`, {
			method = "GET",
		})

		if not result.ok then
			error(`Failed to fetch user sets for UID {user_id}: {result.status} {result.body}`)
		end

		local xml_result = xml.parse(buffer.fromstring(result.body))
		assert(xml_result, `Failed to parse XML for UID {user_id}: {result.body}`)

		local children = xml_result.children :: { [any]: any }

		local mapping = {}
		local creator_name

		-- dump sets
		for index, xml_set in children do
			local set = parse_entry(xml_set)
			print("set:", json.serialize(set, true))

			-- dump set
			do
				if index == 1 then
					creator_name = set.CreatorName
					fs.createDirectory(`dump/users/{set.CreatorName}`, { makeParents = true })
				end

				local file = fs.open(`dump/users/{set.CreatorName}/{set.Name}.json`, "w")
				fs.write(file, json.serialize(set, true))
				fs.close(file)
			end

			table.insert(mapping, `\trequire("@self/{set.Name}")`)

			-- private collections can't be dumped!
			if set.SetType == "private" then
				continue
			end

			-- dump collection
			dump_collection(set.AssetSetId)
			table.insert(collection_mapping, `\t["{set.AssetSetId}"] = require("@self/{set.AssetSetId}")`)
			
			-- servers....
			print(`dumped set {set.Name} for user {set.CreatorName} (user id {user_id})`)
			task.wait(0.5)
		end

		assert(creator_name, `No creator name found for user id {user_id}`)

		-- make typed init.luau file
		do
			local file = fs.open(`dump/users/{creator_name}/init.luau`, "w")
			fs.write(file, `-- generated!\n`)

			fs.write(file, `{SET_TYPE}\n`)

			fs.write(file, "return {\n")
			local entries = table.concat(mapping, ",\n")
			fs.write(file, entries)
			fs.write(file, "\n} :: { Set }")

			fs.close(file)
		end

		table.insert(user_mapping, `\t["{creator_name}"] = require("@self/{creator_name}")`)

		-- dont wreck the servers!
		task.wait(1)
	end

	-- create the top-level users init.luau file
	do
		local file = fs.open("dump/users/init.luau", "w")
		fs.write(file, `-- generated!\n`)

		fs.write(file, `{SET_TYPE}\n`)

		fs.write(file, "return {\n")
		local entries = table.concat(user_mapping, ",\n")
		fs.write(file, entries)
		fs.write(file, "\n} :: { [string]: { Set } }")

		fs.close(file)
	end

	-- create collection mapping file
	do
		local file = fs.open("dump/collections/init.luau", "w")
		fs.write(file, `-- generated!\n`)

		fs.write(file, `{COLLECTION_ENTRY_TYPE}\n`)

		fs.write(file, "return {\n")
		local entries = table.concat(collection_mapping, ",\n")
		fs.write(file, entries)
		fs.write(file, "\n} :: { [string]: { CollectionEntry } }")

		fs.close(file)
	end
end

local function generate_init_luau()
	do
		local file = fs.open("dump/init.luau", "w")
		fs.write(file, `-- generated!\n`)

		fs.write(file, `{SET_TYPE}\n`)
		fs.write(file, `{COLLECTION_ENTRY_TYPE}\n`)

		fs.write(
			file,
			[[
return {
	base = require("@self/base"),
	users = require("@self/users"),
	collections = require("@self/collections")
}
]]
		)

		fs.close(file)
	end
end

-- dump the base categories used by the stamper tool
dump_base_sets()

-- dump user sets (just the core ones!)
dump_user_sets()

-- make the top-level module
generate_init_luau()

print("all done!")
