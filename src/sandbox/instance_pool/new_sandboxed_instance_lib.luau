local RunService = game:GetService("RunService")

local sandbox_types = require("../sandbox_types")
local sandboxer = require("../sandboxer")

local DONT_REPLICATE = { "Dragger" }

--- Creates a sandboxed version of Roblox's `Instance` library
local function new_sandboxed_instance_lib(app: sandbox_types.App)
    local instance_pool

    if RunService:IsClient() then
        instance_pool = app.bag.get(app.bag.entries.client_instance_pool)
    end

    local library = {}

    -- This was added in 2025 so it hasn't been implemented, but it could be in the future
    function library.fromExisting(instance: Instance)
        return Instance.fromExisting(sandboxer.unsandbox(instance))
    end

    --- https://devforum.roblox.com/t/instancelock-instanceunlock-removal/49923
    --- https://devforum.roblox.com/t/what-are-instancelock-and-instanceunlock/31878/2
    --- Deprecated function that prevented other clients from replicating changes to an instance until unlock is called.
    --- future: restore functionality properly.
    function library.Lock(_instance)
        -- instance = sandbox.unsandbox(instance)
        -- assert(typeof(instance) == "Instance")
        
        -- if instance:GetAttribute("locked") and instance:GetAttribute("locked") ~= LOCAL_PLAYER.UserId then
        --     return false
        -- else
        --     return remotes.networkLock.establishLock:InvokeServer(instance)
        -- end

        return true
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
            return sandboxer.sandbox(app, instance)
        end
    else
        function library.new(className: string, parent: Instance?)
            if parent then
                parent = sandboxer.unsandbox(parent)
            end
            
            if table.find(DONT_REPLICATE, className) then
                local instance = Instance.new(className)
                instance.Parent = parent
                return sandboxer.sandbox(app, instance)
            end
    
            assert(instance_pool)
            local instance = instance_pool.pop(className, parent)
            
            if parent ~= nil then
                instance.Parent = parent
            end

            return sandboxer.sandbox(app, instance)
        end
    end

    return setmetatable(library, {
        -- lie our asses off
        __index = function() error("attempt to modify a readonly table") end,
        __newindex = function() error("attempt to modify a readonly table") end
    })
end

return new_sandboxed_instance_lib