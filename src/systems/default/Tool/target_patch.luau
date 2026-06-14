local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local network = require("@layer/network")
local sandbox = require("@layer/sandbox")

local patching = sandbox.patching

local LOCAL_PLAYER = Players.LocalPlayer
local NAME = "humanoid_target"
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- client
-- send target point to server
app.add_system(NAME, function()
	assert(LOCAL_PLAYER)

	local function on_character_added(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10000)

		if humanoid and humanoid:IsA("Humanoid") then
			humanoid:GetPropertyChangedSignal("TargetPoint"):Connect(function()
				network.remotes.unreliable.client.send(
					network.remotes.ids.unreliable.target_point.update,
					humanoid.TargetPoint
				)
			end)
		end
	end

	LOCAL_PLAYER.CharacterAdded:Connect(on_character_added)

	if LOCAL_PLAYER.Character then
		on_character_added(LOCAL_PLAYER.Character)
	end
end, IS_CLIENT)

local humanoids: { [Player]: Humanoid } = {}
local tool_yield_map: { [Tool]: Humanoid } = {}

-- server
-- set humanoid target point based on client reported values
app.add_system(NAME, function()
    local function on_player_added(player: Player)
		local function on_character(character: Model)
            character.ChildAdded:Connect(function(child)
                if child:IsA("Humanoid") and humanoids[player] == nil then
                    humanoids[player] = child:: Humanoid
                elseif child:IsA("Tool") then
                    tool_yield_map[child] = humanoids[player]
                    
                    child.Destroying:Once(function()
                        tool_yield_map[child] = nil
                    end)

                    child:GetPropertyChangedSignal("Parent"):Once(function()
                        tool_yield_map[child] = nil
                    end)
                end
            end)
		end

		player.CharacterAdded:Connect(on_character)

		if player.Character then
			task.spawn(on_character, player.Character)
		end
    end

	Players.PlayerAdded:Connect(on_player_added)

	Players.PlayerRemoving:Connect(function(player)
		humanoids[player] = nil
	end)

    for _, player in Players:GetPlayers() do
        on_player_added(player)
    end

	network.remotes.unreliable.server.subscribe(
		{},
		network.remotes.ids.unreliable.target_point.update,
		function(player: Player, target_point: unknown)
			assert(typeof(target_point) == "Vector3")

			if humanoids[player] then
				humanoids[player].TargetPoint = target_point
			end
		end
	)
end, IS_SERVER)

-- server patch
-- defer activate events until target point is updated
app.add_patch(
	NAME,
	patching.getter_patch {
		classes = { "Tool" },
		keys = { "Activated" },
		enabled = IS_SERVER,
		run = function(context: sandbox.PatchedContext, _key: any)
			local tool = context.unsandboxed_object
            local signal = context.unsandboxed_object["Activated"]

            local function connect(_self, callback)
                assert(typeof(callback) == "function")
                
                return signal:Connect(function()
                    local humanoid = tool_yield_map[tool]

                    if humanoid then
                        print("yield!")
                        humanoid:GetPropertyChangedSignal("TargetPoint"):Wait()
                        print("now call!")
                    end

                    callback()
                end)
            end

            -- future: could do Wait/wait too, but it's unlikely
            -- to be required for now.
			local fake_signal = {
				__index = context.unsandboxed_object,
                Connect = connect,
                connect = connect,
				[patching.symbols.FAKE_TYPE] = typeof(signal),
				[patching.symbols.FAKE_TYPEOF] = typeof(signal),
			}

            setmetatable(fake_signal, fake_signal)

            return signal
		end,
	}
)

return nil