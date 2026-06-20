--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local remotes = require("@layer/network/remotes")
local sandbox_types = require("../sandbox_types")
local instance_pool_remote = require("./instance_pool_remote")

local LOCAL_PLAYER = Players.LocalPlayer

local function instance_pool_client(_app: sandbox_types.App)
    assert(RunService:IsClient(), "instance_pool_client is running on the server!")
    local container = LOCAL_PLAYER:WaitForChild("PlayerGui"):WaitForChild("PoolFactory")
    local class_requests: { [string]: { thread } } = {}

    local function pop(className, parent: Instance?, expand: boolean?)
        local class_container = container:FindFirstChild(className)

        if class_container then
            local instance = class_container:GetChildren()[1]
            
            if not instance then
                expand = true
                print(`waiting for expansion of {className} pool...`)
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
            print(`already waiting for {className} pool expansion, yielding...`)
            table.insert(class_requests[className], coroutine.running())
            coroutine.yield()
            return pop(className, parent, expand)
        else
            class_requests[className] = {}
            print(`requesting expansion of {className} pool from server...`)
            instance_pool_remote:InvokeServer(className)

            for _, thread in class_requests[className] do
                coroutine.resume(thread)
            end

            print("resuming threads!")
            return pop(className, parent, expand)
        end
    end

    return {
        pop = pop
    }
end

return instance_pool_client