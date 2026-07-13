local env_symbols = require("../env_symbols")

local patch_utils = {}

function patch_utils.get_source_script(): LuaSourceContainer?
    for env_level = 2, 6 do
        local result = getfenv(env_level)[env_symbols.SOURCE_SCRIPT]

        if result then
            return result
        end
    end

    return nil
end

return patch_utils