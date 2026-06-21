local remotes = require("@layer/network/remotes")
local server = remotes.reliable.server

local with_players = require("@layer/util/with_players")
local nl_constants = require("../../nl_constants")

local POOL_SIZE = 100

return function()
	local warehouses = {}
	local pools: { [Player]: { [string]: Folder } } = {}

	with_players(function(player)
		local pgui = player:WaitForChild("PlayerGui")

		local warehouse = Instance.new("ScreenGui")
        warehouse.ResetOnSpawn = false
		warehouse.Name = "_Warehouse" -- sync with client!
		warehouse:AddTag(nl_constants.RELOAD_PROTECTION)
		warehouse.Parent = pgui
		warehouses[player] = warehouse

		pools[player] = {}

		return function()
			warehouses[player] = nil
			pools[player] = nil
		end
	end)

	local function make_pool(player: Player, class: string)
		if pools[player][class] then
			return
		end

		local pool = Instance.new("Folder")
		pool.Name = class

		for _ = 1, POOL_SIZE do
			local instance = Instance.new(class)
			instance.Parent = pool
		end

		pools[player][class] = pool
		pool.Parent = warehouses[player]

		pool.ChildRemoved:Connect(function()
			local instance = Instance.new(class)
			instance.Parent = pool
		end)
	end

	server.subscribe({}, remotes.ids.reliable.instance_pool.expand, function(player, class)
        assert(typeof(class) == "string")
        make_pool(player, class)
    end)
end
