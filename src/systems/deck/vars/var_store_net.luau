local vars = require("@layer/vars")

local function build_net_ids()
	local net_to_def: { [number]: vars.SomeDef } = {}
    local id_to_net: { [string]: number } = {}

	for index, value in pairs(vars.def_array) do
		net_to_def[index] = value
        id_to_net[value.id] = index
	end

	return net_to_def, id_to_net
end

local net_to_def, id_to_net = build_net_ids()

local var_store_net = {}

--- builds a table of all dirty values in the var store for networking
function var_store_net.build_dirty_table(var_store: vars.VariableStore)
	local dirty_values = {}

	for def in var_store.dirty do
		dirty_values[id_to_net[def.id]] = vars.modifier.get_var(var_store, def)
	end

    return dirty_values
end

--- packs all values into a network payload
function var_store_net.pack(var_store: vars.VariableStore): { [number]: unknown }
    local payload: { [number]: unknown } = {}

    for index, def in net_to_def do
        payload[index] = vars.modifier.get_var(var_store, def)
    end

    return payload
end

--- validates and unpacks all dirty values into the var store
function var_store_net.unpack_to(var_store: vars.VariableStore, payload: unknown)
    assert(typeof(payload) == "table", "not a table")
    
    for net, value in payload do
        assert(typeof(net) == "number", `invalid key {net}`)
        local var_def = net_to_def[net]
        assert(var_def, `net id {net} is unrecognised`)
        vars.validator.assert_valid(var_def, value)
        vars.modifier.set_var(var_store, var_def, value)
    end
end

return var_store_net
