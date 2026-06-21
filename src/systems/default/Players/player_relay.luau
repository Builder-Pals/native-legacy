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

	signals.Players.PlayerAdded.fire(player)

	-- respawn character to make sure OnCharacterAdded events fire
	if was_character_loaded then
		task.spawn(player.LoadCharacterAsync, player)
	end
end

local function remove_player(player: Player)
	if joined[player] then
		joined[player] = nil
		signals.Players.PlayerRemoving.fire(player)
	end
end

local function mask_players()
	is_masking_enabled = true
	table.clear(joined)
end

app.add_system("player_relay", function(context)
	FakeSignal.wire(signals.Players.PlayerAdded.signal, Players.PlayerAdded, function(player)
		if is_masking_enabled then
			return FakeSignal.SINK
		end

        if player == Players.LocalPlayer then
            -- yea it'd just be a bit weird
            return FakeSignal.SINK
        end

		joined[player] = true
		return sandboxer.sandbox(context, player)
	end)

	FakeSignal.wire(signals.Players.PlayerRemoving.signal, Players.PlayerRemoving, function(player)
		if not joined[player] then
			return FakeSignal.SINK
		end

		joined[player] = nil
		return sandboxer.sandbox(context, player)
	end)
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

				print("sandboxed players:", players)

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
		keys = { "GetChildren", "getChildren" },
		run = function(context)
			return function(_)
				local players = {}

				for player in joined do
					table.insert(players, sandboxer.sandbox(context.sandbox_context, player))
				end

				-- return a table with the players we haven't registered yet removed
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

				print("filtered children:", filtered_children)
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
			return signal_context.signal
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
