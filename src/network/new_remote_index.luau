local bin_utils = require("@layer/util/bin_utils")
local remote_ids = require("./remote_ids")

local function new(remote_event: RemoteEvent)
    local remote_index = {}

    remote_index.server = {}
    remote_index.client = {}

    --- Send data to a client
    function remote_index.server.send<T...>(key: remote_ids.ServerSends<T...>, player: Player, ...: T...)
        remote_event:FireClient(player, key, ...)
    end

    --- Send data to all clients
    function remote_index.server.send_all<T...>(key: remote_ids.ServerSends<T...>, ...: T...)
        remote_event:FireAllClients(key, ...)
    end

    --- Subscribe to all messages from clients
    function remote_index.server.subscribe<T...>(
        scope: bin_utils.Bin, key: remote_ids.ServerSends<T...>,
        callback: (player: Player, ...unknown) -> ()
    )
        local connection = remote_event.OnServerEvent:Connect(function(player: Player, source_key, ...)
            if source_key == key then
                callback(player, ...)
            end
        end)

        local function die()
            connection:Disconnect()
        end

        table.insert(scope, die :: any)
        return die
    end

    --- Send to server
    function remote_index.client.send<T...>(key: remote_ids.ServerSends<T...>, ...: T...)
        remote_event:FireServer(key, ...)
    end

    --- Subscribe to messages from server
    function remote_index.client.subscribe<T...>(
        scope: bin_utils.Bin,
        key: remote_ids.ServerSends<T...>,
        callback: (T...) -> ()
    )
        print("client subbed to", remote_event, key)
        local connection = remote_event.OnClientEvent:Connect(function(source_key, ...)
            if key == source_key then
                callback(...)
            end
        end)
        
        local function die()
            connection:Disconnect()
        end

        table.insert(scope, die :: any)
        return die
    end

    return remote_index
end

return new