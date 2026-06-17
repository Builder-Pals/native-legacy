--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local remotes = require("@layer/network/remotes")
local instance_pool_remote = require("./instance_pool_remote")
local new_server_pool_factory = require("./new_server_pool_factory")

local isRunning = false

local function class_exists(className: string)
    return pcall(function()
        -- selene: allow(must_use)
        Instance.new(className)
    end) == true
end

local function instance_pool_server()
    if isRunning then
        return {}
    end

    assert(RunService:IsServer(), "instance_pool_server should only run on the server!")
    isRunning = true

    local warehouses = {}

    local function on_player_added(player: Player)
        print("making a new pool factory for player", player)
        local container = Instance.new("ScreenGui")
        container.ResetOnSpawn = false
        container.Name = "PoolFactory"
        container.Enabled = false
        container.Parent = player:WaitForChild("PlayerGui")
        warehouses[player] = new_server_pool_factory(container)
    end

    local function on_player_removing(player: Player)
        if warehouses[player] then
            warehouses[player] = nil
        end
    end

    Players.PlayerAdded:Connect(on_player_added)
    Players.PlayerRemoving:Connect(on_player_removing)

    for _, player in Players:GetPlayers() do
        task.spawn(on_player_added, player)
    end

    instance_pool_remote.OnServerInvoke = function(player: Player, class_name: any): Instance?
        assert(typeof(class_name) == "string")
        local warehouse = warehouses[player]

        if not warehouse then
            warn(`{player} doesn't have a warehouse!`)
            return nil
        end

        if class_exists(class_name) then
            return warehouse.pop(class_name)
        end

        return nil
    end

    return {}
end

return instance_pool_server