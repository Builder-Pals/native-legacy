--!strict

local Players = game:GetService("Players")

local remotes = require("@layer/network/remotes")
local instance_pool_remote = require("./instance_pool_remote")
local LOCAL_PLAYER = Players.LocalPlayer

local function runtime_client()
    local container = LOCAL_PLAYER:WaitForChild("PlayerGui"):WaitForChild("PoolFactory")
    local class_requests: { [string]: { thread } } = {}

    local function pop(className, parent: Instance?, expand: boolean?)
        local class_container = container:FindFirstChild(className)

        if class_container then
            local instance = class_container:GetChildren()[1]
            
            if not instance then
                expand = true
                instance = class_container.ChildAdded:Wait()
                task.defer(coroutine.running())
                coroutine.yield()
            end
            
            if not instance:IsDescendantOf(container) then
                -- Someone else took it >:((
                return pop(className, parent, expand)
            end

            instance.Parent = parent

            remotes.reliable.client.send(
                remotes.ids.reliable.instance_pool.pop,
                instance,
                parent,
                if expand then expand else nil
            )

            return instance
        elseif class_requests[className] then
            table.insert(class_requests[className], coroutine.running())
            coroutine.yield()
            return pop(className, parent, expand)
        else
            class_requests[className] = {}
            instance_pool_remote:InvokeServer(className)

            for _, thread in class_requests[className] do
                coroutine.resume(thread)
            end

            return pop(className, parent, expand)
        end
    end

    return {
        pop = pop
    }
end

export type RuntimeClient = typeof(runtime_client())

return runtime_client