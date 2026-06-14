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

	local function on_character(character: Model)
		local targetPoint = Vector3.zero

		local function on_child(child: Instance)
			if child:IsA("Humanoid") then
				child:GetPropertyChangedSignal("TargetPoint"):Connect(function()
					targetPoint = child.TargetPoint

					network.remotes.unreliable.client.send(
						network.remotes.ids.unreliable.target_point.update,
						targetPoint
					)
				end)
			elseif child:IsA("Tool") then
				local activate_hook = child.Activated:Connect(function()
					-- Humanoid.TargetPoint isn't updated until later in the frame! 
					-- defer to avoid sending the last mouse position.
					-- we can't easily rely on the event, as it only fires off if the mouse is moved.
					task.defer(function()
						network.remotes.unreliable.client.send(
							network.remotes.ids.unreliable.target_point.tool_activate,
							targetPoint
						)
					end)
				end)

				child.Destroying:Once(function()
					activate_hook:Disconnect()
				end)

				child:GetPropertyChangedSignal("Parent"):Once(function()
					activate_hook:Disconnect()
				end)
			end
		end

		character.ChildAdded:Connect(function(child)
			on_child(child)
		end)

		for _, child in character:GetChildren() do
			on_child(child)
		end
	end

	LOCAL_PLAYER.CharacterAdded:Connect(on_character)

	if LOCAL_PLAYER.Character then
		on_character(LOCAL_PLAYER.Character)
	end
end, IS_CLIENT)

local humanoids: { [Player]: Humanoid } = {}
local tool_humanoid_map: { [Tool]: Humanoid } = {}
local target_timestamps: { [Player]: number } = {}

local function player_from_humanoid(humanoid: Humanoid): Player?
	for player, value in humanoids do
		if value == humanoid then
			return player
		end
	end

	return nil
end

-- server
-- set humanoid target point based on client reported values
app.add_system(NAME, function()
	local function on_player_added(player: Player)
		target_timestamps[player] = 0

		local function on_character(character: Model)
			local function on_child(child: Instance)
				if child:IsA("Humanoid") and humanoids[player] == nil then
					humanoids[player] = child :: Humanoid
				elseif child:IsA("Tool") then
					tool_humanoid_map[child] = humanoids[player]
					
					child.Destroying:Once(function()
						tool_humanoid_map[child] = nil
					end)

					child:GetPropertyChangedSignal("Parent"):Once(function()
						tool_humanoid_map[child] = nil
					end)
				end
			end

			character.ChildAdded:Connect(function(child)
				on_child(child)
			end)

			for _, child in character:GetChildren() do
				on_child(child)
			end
		end

		player.CharacterAdded:Connect(on_character)

		if player.Character then
			task.spawn(on_character, player.Character)
		end
	end

	Players.PlayerAdded:Connect(on_player_added)

	Players.PlayerRemoving:Connect(function(player)
		humanoids[player] = nil
		target_timestamps[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		on_player_added(player)
	end

	network.remotes.unreliable.server.subscribe(
		{},
		network.remotes.ids.unreliable.target_point.update,
		function(player: Player, target_point: unknown)
			assert(typeof(target_point) == "Vector3")
			local humanoid = humanoids[player]

			if humanoid then
				humanoids[player].TargetPoint = target_point
				target_timestamps[player] = os.clock()
			end
		end
	)
end, IS_SERVER)

-- server patch
-- yield activate events until target point is sent by the client
app.add_patch(
	NAME,
	patching.getter_patch {
		classes = { "Tool" },
		keys = { "Activated" },
		run = function(context: sandbox.PatchedContext, _key: any)
			local tool = context.unsandboxed_object
			local signal = context.unsandboxed_object["Activated"] :: RBXScriptSignal

			local function connect(_self, callback)
				assert(typeof(callback) == "function")

				local connection = signal:Connect(function()
					local humanoid = tool_humanoid_map[tool]
					local player = humanoid and player_from_humanoid(humanoid)

					-- fire as normal for NPC held tools
					if not player then
						print("fire standard :(")
						callback()
					end
				end)

				local unsub
				unsub = network.remotes.unreliable.server.subscribe(
					{},
					network.remotes.ids.unreliable.target_point.tool_activate,
					function(player, target_point)
						if not connection.Connected then
							assert(unsub)
							unsub()
							return
						end

						assert(typeof(target_point) == "Vector3", "received invalid target point")

						local tool_player = tool.Parent and Players:GetPlayerFromCharacter(tool.Parent)

						if player == tool_player then
							local humanoid = tool_humanoid_map[tool]

							if humanoid then
								humanoid.TargetPoint = target_point
							end

							print("fire good", target_point)
							callback()
						end
					end
				)

				return connection
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

			return fake_signal
		end,
	},
	IS_SERVER
)

return nil
