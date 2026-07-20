local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local FakeSignal = require("@layer/util/FakeSignal")
local player_relay_state = require("./player_relay_state")
local routing = require("@layer/routing")

local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

--- When masking is enabled, players are hidden and their join events are withheld.
local state = player_relay_state.new(Players:GetPlayers())

-- Prevents RBXScriptSignals from causing sandbox escapes and restores deprecated methods.
local signals = {
	Players = {
		PlayerAdded = FakeSignal.new(),
		PlayerRemoving = FakeSignal.new(),
		ChildAdded = FakeSignal.new(),
	},
}

local key_map = {
	playeradded = signals.Players.PlayerAdded,
	playerremoving = signals.Players.PlayerRemoving,
}

local function replay_player(player: Player)
	if not state.add(player) then
		return
	end

	-- Reload characters on the server so the new game's CharacterAdded listeners run.
	if RunService:IsServer() and player.Character then
		player.Character:Destroy()
	end

	FakeSignal.fire(signals.Players.PlayerAdded, player)
	FakeSignal.fire(signals.Players.ChildAdded, player)

	if RunService:IsServer() and Players.CharacterAutoLoads then
		task.spawn(player.LoadCharacterAsync, player)
	end
end

local function remove_player(player: Player)
	if state.remove(player) then
		FakeSignal.fire(signals.Players.PlayerRemoving, player)
	end
end

local function mask_players(): number
	return state.mask()
end

local function release_players(expected_generation: number?): boolean
	if not state.release(expected_generation) then
		return false
	end

	for _, player in Players:GetPlayers() do
		replay_player(player)
	end

	return true
end

app.add_system("player_relay", function(context)
	local sandbox_value_processor = FakeSignal.new_processor(function(callback)
		return function(value)
			callback(sandboxer.sandbox(context, value))
		end
	end)

	FakeSignal.add_processor(signals.Players.PlayerAdded, sandbox_value_processor)
	FakeSignal.add_processor(signals.Players.PlayerRemoving, sandbox_value_processor)
	FakeSignal.add_processor(signals.Players.ChildAdded, sandbox_value_processor)

	-- Maintain visibility once per engine event, independently of how many game listeners exist.
	Players.PlayerAdded:Connect(function(player)
		if state.is_masking() then
			return
		end

		state.add(player)

		-- LocalPlayer should be queryable, but replaying its real arrival on the client is unexpected.
		if player ~= Players.LocalPlayer then
			FakeSignal.fire(signals.Players.PlayerAdded, player)
		end
	end)

	Players.ChildAdded:Connect(function(child)
		if not child:IsA("Player") then
			FakeSignal.fire(signals.Players.ChildAdded, child)
			return
		end

		if state.is_masking() then
			return
		end

		state.add(child)

		if child ~= Players.LocalPlayer then
			FakeSignal.fire(signals.Players.ChildAdded, child)
		end
	end)

	Players.PlayerRemoving:Connect(remove_player)

	-- Close the gap between the module's initial snapshot and event subscription.
	if not state.is_masking() then
		for _, player in Players:GetPlayers() do
			state.add(player)
		end
	end

	-- Place loading happens on the server. Mirror its replicated freeze/thaw lifecycle
	-- so client scripts get the same withheld and replayed player events.
	if RunService:IsClient() then
		local client_generation

		local function sync_load_state()
			if routing.ROOT:GetAttribute("frozen") then
				client_generation = mask_players()
			elseif client_generation then
				local generation = client_generation
				client_generation = nil

				task.delay(1, function()
					release_players(generation)
				end)
			end
		end

		routing.ROOT:GetAttributeChangedSignal("frozen"):Connect(sync_load_state)
		sync_load_state()
	end
end)

-- Server/client: return the relay-maintained list so unreplayed players stay hidden.
app.add_patch(
	"player_relay_get_players",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "GetPlayers", "getPlayers" },
		run = function(context)
			return function(_)
				local players = {}

				for _, player in state.get_players() do
					table.insert(players, sandboxer.sandbox(context.sandbox_context, player))
				end

				return players
			end
		end,
	}
)

-- Server/client: many old scripts used GetChildren instead of GetPlayers.
app.add_patch(
	"player_relay_get_children",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "GetChildren", "getChildren", "children" },
		run = function(context)
			return function(_)
				local children = context.unsandboxed_object:GetChildren()
				local filtered_children = {}

				for _, child in children do
					if not child:IsA("Player") or state.contains(child) then
						table.insert(filtered_children, sandboxer.sandbox(context.sandbox_context, child))
					end
				end

				return filtered_children
			end
		end,
	}
)

app.add_patch(
	"player_relay_events",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "playerAdded", "PlayerAdded", "playerRemoving", "PlayerRemoving" },
		run = function(_, key)
			local signal_context = key_map[key:lower()]
			assert(signal_context, `{key:lower()} missing from key map!`)
			return signal_context
		end,
	}
)

-- Many old scripts listen to ChildAdded instead of PlayerAdded.
app.add_patch(
	"player_relay_child_added_event",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "childAdded", "ChildAdded" },
		run = function(_)
			return signals.Players.ChildAdded
		end,
	}
)

return {
	mask_players = mask_players,
	release_players = release_players,
	remove_player = remove_player,
	is_current_generation = state.is_current_generation,
}
