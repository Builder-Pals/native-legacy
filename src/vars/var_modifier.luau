local native_var_defs = require("./native_var_defs")
local t = require("./var_types")

local var_modifier = {}

function var_modifier.new(): t.VariableStore
	local variables = {}

	for _, def in native_var_defs.definition_array do
		variables[def.id] = def.default
	end

	return {
		values = variables,
		dirty = {}
	}
end

function var_modifier.set_var<T>(variables: t.VariableStore, def: t.Def<T>, value: T)
    variables.values[def.id] = value
    variables.dirty[def] = true
end

function var_modifier.get_var<T>(variables: t.VariableStore, def: t.SomeDef): T
    local value = variables.values[def.id]
	assert(value ~= nil, `missing var {def.id}}`)
	return value
end

return var_modifier
