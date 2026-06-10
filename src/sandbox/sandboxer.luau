local patch_symbols = require("@layer/patching/patch_symbols")
local sandbox_types = require("./sandbox_types")
local sandbox_wrapper = require("./sandbox_wrapper")

--- Takes values in/out of the Sandbox
local sandboxer = {}

--- Puts a value into the sandbox, applying any relevant patches.
function sandboxer.sandbox(context: sandbox_types.SandboxContext, value: unknown)
    return sandbox_wrapper(context, value)
end

--- Gets the underlying value from a sandboxed object.
--- If its not sandboxed, the same object will be returned.
function sandboxer.unsandbox<T>(value: T)
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

--- Sandboxes multiple values
function sandboxer.sandbox_tuple(context: sandbox_types.SandboxContext)
    return function(...: any)
        local packed = table.pack(...)
        local result = {}

        for key, value in packed do
            result[key] = sandboxer.sandbox(context, value)
        end

        return table.unpack(result)
    end
end

--- Unsandboxes multiple values
function sandboxer.unsandbox_tuple(...: any)
    local packed = table.pack(...)
    local result = {}

    for key, value in packed do
        result[key] = sandboxer.unsandbox(value)
    end

    return table.unpack(result)
end

return sandboxer