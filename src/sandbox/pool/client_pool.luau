local Players = game:GetService("Players")
local remotes = require("../../network/remotes")
local Action = require("@layer/util/Action")
local replicated_nil = require("@layer/systems/default/replicated_nil")
local defiltering = require("../defiltering")

return function()
	local warehouse = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("_Warehouse")
	local warehouse_data: { [string]: { Instance } } = {}
	local instance_tickets: { [string]: { {false | Instance} } } = {}

	local function on_folder_added(pool_folder: Instance)
		if not pool_folder:IsA("Folder") then
			return
		end

		local class = pool_folder.Name
		local pool: { Instance } = {}
		local threads = instance_tickets[class] or {}

		warehouse_data[class] = pool
		instance_tickets[class] = threads

		local function on_poolee_added(instance: Instance)
			if not instance:IsA(class) then
				warn(`[pool] invalid - child added to {class} pool, but it's not a {class}.`)
				return
			end

			local ticket = table.remove(threads)

			if ticket then
				print("[pool] resuming ticket")
				ticket[1] = instance
			else
				table.insert(pool, instance)
			end
		end

		local function on_poolee_removed(instance: Instance)
			local index = table.find(pool, instance)

			if index then
				table.remove(pool, index)
			end
		end

		for _, child in pool_folder:GetChildren() do
			on_poolee_added(child)
		end

		pool_folder.ChildAdded:Connect(on_poolee_added)
		pool_folder.ChildRemoved:Connect(on_poolee_removed)
	end

	-- we used to yield threads here instead of polling, but they're shaky inside of metamethods - causing
	-- silent infinite yield problems (that limitation is documented).
	local function pool_yield(class: string): Instance
		print(`[pool] empty - waiting for {class}...`)

		if not instance_tickets[class] then
			instance_tickets[class] = {}
		end

		local ticket: { Instance | false } = {false}

		table.insert(instance_tickets[class], ticket)
		
		while not ticket[1] do
			task.wait()
		end

		return ticket[1] :: Instance
	end

	for _, child in warehouse:GetChildren() do
		on_folder_added(child)
	end

	warehouse.ChildAdded:Connect(on_folder_added)

	local function pop_async(class: string): Instance
		if not warehouse_data[class] then
			-- Validate through the engine so invalid and non-creatable classes fail
			-- at the call site instead of waiting forever for a pool expansion.
			local ok, validation_instance = pcall(Instance.new, class)

			if not ok then
				error(validation_instance, 2)
			end

			validation_instance:Destroy()

			-- if there's a yielding_threads table for the class, we must have already requested
			-- for the pool to be expanded. so don't spam the server :P
			if not instance_tickets[class] then
				-- request for server to make a new pool for the class.
				remotes.reliable.client.send(remotes.ids.reliable.instance_pool.expand, class)
			end

			return pool_yield(class)
		end

		local poolee = table.remove(warehouse_data[class])

		if not poolee then
			return pool_yield(class)
		end

		-- make sure its parented elsewhere so that the server knows it's no longer in the pool.
		Action.invoke(defiltering.events.send_property, poolee, "Parent", replicated_nil, {
			local_value = nil,
			use_local_value = true,
		})

		return poolee
	end

	local function discard(instance: Instance)
		Action.invoke(defiltering.events.cancel_instance, instance)
		Action.invoke(defiltering.events.send_property, instance, "__d", true)
		instance:Destroy()
	end

	return {
		pop = pop_async,
		discard = discard,
	}
end
