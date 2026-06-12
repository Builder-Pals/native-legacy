local RunService = game:GetService("RunService")

local instance_pool_client = require("./instance_pool_client")
local sandbox_types = require("../sandbox_types")
local sandboxer = require("../sandboxer")

local DONT_REPLICATE = { "Dragger" }

--- Creates a sandboxed version of Roblox's `Instance` library
local function new_sandboxed_instance_lib(sandbox_context: sandbox_types.SandboxContext, pool: instance_pool_client.RuntimeClient?)
    local library = {}

    -- This was added in 2025 so it hasn't been implemented, but it could be in the future
    function library.fromExisting(instance: Instance)
        return Instance.fromExisting(sandboxer.unsandbox(instance))
    end

    --- https://devforum.roblox.com/t/instancelock-instanceunlock-removal/49923
    --- Deprecated function that prevented other clients from replicating changes to an instance until unlock is called.
    function library.Lock(_instance)
        -- instance = sandbox.unsandbox(instance)
        -- assert(typeof(instance) == "Instance")
        
        -- if instance:GetAttribute("locked") and instance:GetAttribute("locked") ~= LOCAL_PLAYER.UserId then
        --     return false
        -- else
        --     return remotes.networkLock.establishLock:InvokeServer(instance)
        -- end
    end

    function library.Unlock(_instance)
        -- instance = sandbox.unsandbox(instance)
        -- assert(typeof(instance) == "Instance")
        -- remotes.networkLock.unlock:FireServer(instance)
    end

    if RunService:IsServer() then
        function library.new(className: string, parent: Instance?)
            if parent then
                parent = sandboxer.unsandbox(parent)
            end

            local instance = Instance.new(className)
            instance.Parent = parent
            return sandboxer.sandbox(sandbox_context, instance)
        end
    else
        assert(pool)

        function library.new(className: string, parent: Instance?)
            if parent then
                parent = sandboxer.unsandbox(parent)
            end
            
            if table.find(DONT_REPLICATE, className) then
                local instance = Instance.new(className)
                instance.Parent = parent
                return sandboxer.sandbox(sandbox_context, instance)
            end
    
            local instance = pool.pop(className, parent)
            
            if parent ~= nil then
                instance.Parent = parent
            end

            return sandboxer.sandbox(sandbox_context, instance)
        end
    end

    return setmetatable(library, {
        __index = function() error("attempt to modify a readonly table") end,
        __newindex = function() error("attempt to modify a readonly table") end
    })
end

return new_sandboxed_instance_lib