local patch_symbols = require("./patching/patch_symbols")
local virtual_reverser = require("@layer/sandbox/virtual_instance/virtual_reverser")

--- Gets the underlying value from a sandboxed object.
--- If its not sandboxed, the same object will be returned.
return function<T>(value: T)
    local t = typeof(value)

    if t ~= "table" then
        return value
    end

    local success, unsandboxed_object = xpcall(function()
        return rawget(value :: { [any]: any }, patch_symbols.UNSANDBOXED_OBJECT)
    end, function()
        warn(debug.traceback("Failed to retrieve unsandboxed object"))
    end)

    if success then
        if t == "Instance" then
            return virtual_reverser(unsandboxed_object :: Instance)
        else
            return unsandboxed_object
        end
    end

    return value
end