local sandbox_types = require("@layer/sandbox/sandbox_types")
local sandboxer = require("@layer/sandbox/sandboxer")

return function(app: sandbox_types.App)
    local lib = {}

    function lib.new(class: string, parent: Instance?): Instance
        local instance = Instance.new(class)
        instance.Parent = if parent == nil then parent else sandboxer.unsandbox(parent)
        return sandboxer.sandbox(app, instance)
    end

    -- this was added in 2025, but why not!
    function lib.fromExisting(instance: Instance)
        return sandboxer.sandbox(app, Instance.fromExisting(sandboxer.unsandbox(instance)))
    end

    --- https://devforum.roblox.com/t/instancelock-instanceunlock-removal/49923
    --- https://devforum.roblox.com/t/what-are-instancelock-and-instanceunlock/31878/2
    --- Deprecated function that prevented other clients from replicating changes to an instance until unlock is called.
    --- future: restore functionality properly.
    function lib.Lock(_instance)
        -- instance = sandbox.unsandbox(instance)
        -- assert(typeof(instance) == "Instance")
        
        -- if instance:GetAttribute("locked") and instance:GetAttribute("locked") ~= LOCAL_PLAYER.UserId then
        --     return false
        -- else
        --     return remotes.networkLock.establishLock:InvokeServer(instance)
        -- end

        return true
    end

    function lib.Unlock(_instance)
        -- instance = sandbox.unsandbox(instance)
        -- assert(typeof(instance) == "Instance")
        -- remotes.networkLock.unlock:FireServer(instance)
    end

    table.freeze(lib)
    return lib
end