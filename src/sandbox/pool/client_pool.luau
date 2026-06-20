local Players = game:GetService("Players")
local remotes = require("../../network/remotes")

return function()
	local warehouse = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("_Warehouse")
	local warehouse_data: { [string]: { Instance } } = {}
	local yielding_threads: { [string]: { thread } } = {}

	local function on_folder_added(pool_folder: Instance)
		if not pool_folder:IsA("Folder") then
			return
		end

		local class = pool_folder.Name
		local pool: { Instance } = {}
		local threads = yielding_threads[class] or {}

		warehouse_data[class] = pool
		yielding_threads[class] = threads

		local function on_poolee_added(instance: Instance)
			if not instance:IsA(class) then
				return
			end

			local thread = table.remove(threads)

			if thread then
				coroutine.resume(thread, instance)
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

	local function pool_yield(class: string): Instance
		local current = coroutine.running()

		if not yielding_threads[class] then
			yielding_threads[class] = {}
		end

		table.insert(yielding_threads[class], current)
		return coroutine.yield()
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
            if not yielding_threads[class] then
				-- request for server to make a new pool for the class.
				remotes.reliable.client.send(remotes.ids.reliable.instance_pool.expand, class)
			end

			return pool_yield(class)
		end

		local poolee = table.remove(warehouse_data[class])

		if not poolee then
			return pool_yield(class)
		end

		poolee.Parent = nil

		return poolee
	end

	return pop_async
end
