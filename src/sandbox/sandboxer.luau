local sandbox_types = require("./sandbox_types")
local sandbox_wrapper = require("./sandbox_wrapper")
local unsandbox = require("./unsandbox")

--- For pulling values in/out of the Sandbox
local sandboxer = {}

--- Puts a value into the sandbox, applying any relevant patches.
function sandboxer.sandbox(context: sandbox_types.App, value: unknown)
    return sandbox_wrapper(context, value)
end

sandboxer.unsandbox = unsandbox

--- Sandboxes multiple values
function sandboxer.sandbox_tuple(context: sandbox_types.App)
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