local sandbox_types = require("@layer/sandbox/sandbox_types")
local sandboxer = require("@layer/sandbox/sandboxer")
local env_symbols = require("../env_symbols")
local script_stalling = require("../script_stalling")

local NEVER_POOL = {
    Dragger = true -- dragger's parent is locked to 'NULL'
}

local function get_context()
    local ok, result = pcall(function()
        return getfenv(2)[env_symbols.SOURCE_SCRIPT]
    end)

    return if ok then result else nil
end

return function(app: sandbox_types.App)
    local lib = {}

    local function op(class: string, parent: Instance?): unknown
        local instance = app.client_pool(class)
        local sandboxed = sandboxer.sandbox(app, instance)

        if parent ~= nil then
            sandboxed.Parent = parent -- done on the sandboxed object for networking / allowing patches to apply
        end

        return sandboxed
    end

    function lib.new(class: string, parent: Instance?): unknown
        if NEVER_POOL[class] then
            local local_instance = Instance.new(class)
            
            if parent ~= nil then
                local_instance.Parent = parent
            end

            return sandboxer.sandbox(app, local_instance)
        end

        local script_context = get_context()
        
        if script_context then
            return script_stalling.with(script_context, function()
                return op(class, parent)
            end)
        else
            warn(`no script context\n{debug.traceback()}`)
            return op(class, parent)
        end
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