local patch_symbols = require("./patching/patch_symbols")

--- Gets the underlying value from a sandboxed object.
--- If its not sandboxed, the same object will be returned.
return function<T>(value: T)
    if typeof(value) ~= "table" then
        return value
    end

    local success, unsandboxed_object = xpcall(function()
        return rawget(value :: { [any]: any }, patch_symbols.UNSANDBOXED_OBJECT)
    end, function()
        warn(debug.traceback("Failed to retrieve unsandboxed object"))
    end)

    return if success then unsandboxed_object else value
end