--!nonstrict

export type Bin = { [any]: any }

--- A collection of utilities for manual memory management.
local bin_utils = {}

function bin_utils.empty(taskOrBin: any)
	local taskType = typeof(taskOrBin)

	if taskType == "Instance" then
		taskOrBin:Destroy()
	elseif taskType == "RBXScriptConnection" then
		taskOrBin:Disconnect()
	elseif taskType == "function" then
		taskOrBin()
	elseif taskType == "table" then
		if typeof(taskOrBin.destroy) == "function" then
			taskOrBin:destroy()
		elseif typeof(taskOrBin.Destroy) == "function" then
			taskOrBin:Destroy()
		elseif typeof(taskOrBin.doCleanup) == "function" then
			-- Fusion
			taskOrBin:doCleanup()
		elseif taskOrBin[1] ~= nil then
			for _, subtask in taskOrBin do
				bin_utils.empty(subtask)
			end

			table.clear(taskOrBin)
		end
	elseif taskType == "thread" then
		task.cancel(taskOrBin)
	end
end

--[=[
	Returns sugar for managing a table of cleanup tasks.

	```luau
	local bin_add, bin_empty = GarbageUtil.makeBin({})

	-- Add some tasks

	bin_add(function()
		print("Hello, world!")
	end)

	bin_add(Instance.new("Part"))

	bin_add(workspace.ChildAdded)

	-- Now destroy everything in the bin

	bin_empty()
	```
]=]
function bin_utils.make_bin(tabl: {})
	return function(item: unknown)
		table.insert(tabl, item)
		return item
	end, function()
		bin_utils.empty(tabl)
	end
end

do
	local warning_key = {}

	local function multi_clean_warning()
		warn(`Derived scopes should never be cleaned more than once\n{debug.traceback()}`)
	end

	function bin_utils.derive(parent: Bin, child: Bin)
		local key = {}
		parent[key] = child

		table.insert(child, function()
			parent[key] = nil
			child[warning_key] = function()
				child[warning_key] = multi_clean_warning
			end
		end)

		return child
	end
end

return bin_utils