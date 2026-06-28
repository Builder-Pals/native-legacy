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
				warn(`child added to {class} pool, but it's not a {class}.`)
				return
			end

			local ticket = table.remove(threads)

			if ticket then
				print("there's a ticket open - resuming it now")
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
		print(`waiting for {class}...`)

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
		-- we use Instance.new here to throw an error if the class is invalid
		if not warehouse_data[class] and Instance.new(class) then
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
		Action.invoke(defiltering.events.send_property, poolee, "Parent", replicated_nil)

		poolee.Parent = nil

		return poolee
	end

	return pop_async
end
