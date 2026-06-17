--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Action = require("../../util/Action")
local defilterer_events = require("../defiltering/defilterer_events")
local virtual_instance = require("../virtual_instance")

local sandbox_types = require("../sandbox_types")
local sandboxer = require("../sandboxer")
local instance_pool_remote = require("./instance_pool_remote")

local LOCAL_PLAYER = Players.LocalPlayer

local function instance_pool_client(app: sandbox_types.App)
	assert(RunService:IsClient(), "instance_pool_client is running on the server!")
	local container = LOCAL_PLAYER:WaitForChild("PlayerGui"):WaitForChild("PoolFactory")

	local container_map: { [string]: Instance } = {}
	local pending_virtual: { [string]: { Instance } } = {}
    local pending_expand_requests: { [string]: true } = {}

	local function get(className: string, parent: Instance?)
        local class_container = container_map[className]

        if class_container then
            local child = class_container:GetChildren()[1]

            if child then
                print("[popping] instant popped", child)

                child.Parent = parent
                Action.invoke(defilterer_events.send_property, child, "Parent", parent)

                return child
            end
        end
        
        print("virtualizing", className)

		local v = virtual_instance.util.new(className)
        v.Parent = parent

        pending_virtual[className] = pending_virtual[className] or {}
		table.insert(pending_virtual[className], v)

        if not pending_expand_requests[className] then
            print("[expansion] asking server to expand", className)
            pending_expand_requests[className] = true
            
            task.spawn(function()
                instance_pool_remote:InvokeServer(className)
                print("[expansion] \texpansion granted")
                pending_expand_requests[className] = nil
            end)
        end

		return v
	end

    local function handle_class_container(class_container: Instance)
        local class = class_container.Name
        pending_virtual[class] = pending_virtual[class] or {}
        container_map[class] = class_container

        local function on_child_added(child: Instance)
            local pending = table.remove(pending_virtual[class])

            if pending ~= nil then
                -- NEED TO CHECK: does this need to be deferred?
                child.Parent = nil
                virtual_instance.util.resolve(pending, child)
                print("[popping] resolved virtual instance for", class, child)
            end
        end
        
        class_container.ChildAdded:Connect(on_child_added)

        for _, child in class_container:GetChildren() do
            on_child_added(child)
        end
    end

	local function pop(className, parent: Instance?)
		local result = get(className, parent)
        return sandboxer.sandbox(app, result)
	end

    for _, class_container in container:GetChildren() do
        handle_class_container(class_container)
    end

    container.ChildAdded:Connect(handle_class_container)

	return {
		pop = pop,
	}
end

return instance_pool_client
