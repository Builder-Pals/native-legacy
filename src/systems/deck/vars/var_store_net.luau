local vars = require("@layer/vars")

local function build_net_ids()
	local net_to_def: { [number]: vars.SomeDef } = {}
	local id_to_net: { [string]: number } = {}

	for index, value in vars.def_array do
		net_to_def[index] = value
		id_to_net[value.id] = index
	end

	return net_to_def, id_to_net
end

local net_to_def, id_to_net = build_net_ids()

local var_store_net = {}

--- builds a table of all dirty values in the var store for networking
function var_store_net.build_dirty_table(var_store: vars.VariableStore)
	local dirty_values: { [string]: unknown } = {}

	for def in var_store.dirty do
		local net_id = assert(id_to_net[def.id], `variable {def.id} has no network ID`)
		dirty_values[tostring(net_id)] = vars.modifier.get_var(var_store, def :: vars.Def)
	end

	return dirty_values
end

--- packs all values into a network payload
function var_store_net.pack(var_store: vars.VariableStore): { [string]: unknown }
	local payload: { [string]: unknown } = {}

	for index, def in net_to_def do
		payload[tostring(index)] = vars.modifier.get_var(var_store, def :: vars.Def)
	end

	return payload
end

--- Validates and unpacks values into the store. Replicated values are clean by
--- default so they are not echoed back to their sender.
function var_store_net.unpack_to(var_store: vars.VariableStore, payload: unknown, mark_dirty: boolean?)
	assert(typeof(payload) == "table", "not a table")
	local validated = {}

	for net, value in payload :: { [unknown]: unknown } do
		assert(typeof(net) == "string", `invalid key {net}`)
		local net_id = tonumber(net)
		assert(net_id and tostring(net_id) == net, `invalid key {net}`)
		local var_def = net_to_def[net_id]
		assert(var_def, `net id {net} is unrecognised`)
		vars.validator.assert_valid(var_def, value)
		table.insert(validated, { def = var_def, value = value })
	end

	for _, entry in validated do
		vars.modifier.set_var(var_store, entry.def :: vars.Def, entry.value, mark_dirty == true)
	end
end

--- Takes a snapshot of locally changed values and marks those values clean.
function var_store_net.take_dirty_table(var_store: vars.VariableStore): { [string]: unknown }
	local dirty_values = var_store_net.build_dirty_table(var_store)
	table.clear(var_store.dirty)
	return dirty_values
end

return var_store_net
