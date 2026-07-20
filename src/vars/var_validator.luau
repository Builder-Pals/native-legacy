local var_types = require("./var_types")

local validators = {
    singleton = function<T>(def: var_types.SingletonDef<T>, x)
        assert(table.find(def.options, x), `invalid value {x} for singleton {def.id}`)
        return x
    end,

    float = function(def: var_types.FloatDef, x)
        assert(typeof(x) == "number", `invalid value {x} for float {def.id}`)
        if def.clamp then
            assert(x >= def.clamp.min and x <= def.clamp.max, `value {x} for float {def.id} is out of range`)
        end
        return x
    end,

    boolean = function(def: var_types.BooleanDef, x)
        assert(typeof(x) == "boolean", `invalid value {x} for boolean {def.id}`)
        return x
    end,
}

local var_validator = {}

function var_validator.assert_valid(def: var_types.SomeDef, x)
    local validator = validators[def.type]
    assert(validator, `no validator for type {def.type}`)
    return validator(def, x)
end

return var_validator