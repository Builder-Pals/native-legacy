local Players = game:GetService("Players")
local app = require("@layer/app")
local FakeSignal = require("@layer/util/FakeSignal")

local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

--- when masking is enabled, players will be hidden and their join events will be sunk.
local is_masking_enabled = false
local joined = {}

for _, player in Players:GetPlayers() do
	joined[player] = true
end

-- prevents RBXScriptSignals from causing sandbox escapes and 'restores' deprecated methods

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

local function add_player(player: Player)
	joined[player] = true

	local was_character_loaded = player.Character ~= nil

	-- reload the character
	if player.Character then
		player.Character:Destroy()
	end

	FakeSignal.fire(signals.Players.PlayerAdded, player)
	FakeSignal.fire(signals.Players.ChildAdded, player)

	-- respawn character to make sure OnCharacterAdded events fire
	if was_character_loaded then
		task.spawn(player.LoadCharacterAsync, player)
	end
end

local function remove_player(player: Player)
	if joined[player] then
		joined[player] = nil
		FakeSignal.fire(signals.Players.PlayerRemoving, player)
	end
end

local function mask_players()
	is_masking_enabled = true
	table.clear(joined)
end

app.add_system("player_relay", function(context)
	local function handle_player_added(player: Player)
		if is_masking_enabled then
			return FakeSignal.SINK
		end

		if player == Players.LocalPlayer then
			-- yea it'd just be a bit weird
			return FakeSignal.SINK
		end

		joined[player] = true
		return sandboxer.sandbox(context, player)
	end

	local player_added_processor = FakeSignal.new_processor(function(callback)
		return function(player)
			callback(handle_player_added(player))
		end
	end)

	local player_child_processor = FakeSignal.new_processor(function(callback)
		return function(child)
			if not child:IsA("Player") then
				callback(sandboxer.sandbox(context, child))
				return
			end

			callback(handle_player_added(child))
		end
	end)

	local player_removing_processor = FakeSignal.new_processor(function(callback)
		return function(player)
			if not joined[player] then
				return
			end

			joined[player] = nil
			callback(sandboxer.sandbox(context, player))
		end
	end)

	FakeSignal.bind(signals.Players.PlayerAdded, Players.PlayerAdded, player_added_processor)
	FakeSignal.bind(signals.Players.ChildAdded, Players.ChildAdded, player_child_processor)
	FakeSignal.bind(signals.Players.PlayerRemoving, Players.PlayerRemoving, player_removing_processor)
end)

-- server/client
-- returns a self-maintained list of players, so that it doesn't reveal players before we've played there join events.
app.add_patch(
	"player_relay_get_players",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "GetPlayers", "getPlayers" },
		run = function(context)
			return function(_)
				local players = {}

				for player in joined do
					table.insert(players, sandboxer.sandbox(context.sandbox_context, player))
				end

				return players
			end
		end,
	}
)

-- server/client
-- many old scripts used to use GetChildren instead of GetPlayers!
app.add_patch(
	"player_relay_get_children",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "GetChildren", "getChildren", "children" },
		run = function(context)
			return function(_)
				local players = {}

				for player in joined do
					table.insert(players, sandboxer.sandbox(context.sandbox_context, player))
				end

				-- return a table without the players we haven't registered yet
				local children = context.unsandboxed_object:GetChildren()
				local filtered_children = {}

				for _, child in children do
					if not child:IsA("Player") then
						table.insert(filtered_children, child)
						continue
					end

					if table.find(players, child) then
						table.insert(filtered_children, child)
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

-- MANY old scripts listen to ChildAdded instead of PlayerAdded. this is because society is evil.
app.add_patch(
	"player_relay_events",
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

	release_players = function()
		is_masking_enabled = false

		for _, player in Players:GetPlayers() do
			add_player(player)
		end
	end,

	remove_player = remove_player,
}
