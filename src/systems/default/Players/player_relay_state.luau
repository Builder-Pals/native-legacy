local player_relay_state = {}

function player_relay_state.new(initial_players)
	local generation = 0
	local is_masking = false
	local joined = {}

	for _, player in initial_players do
		joined[player] = true
	end

	local state = {}

	function state.add(player): boolean
		if is_masking or joined[player] then
			return false
		end

		joined[player] = true
		return true
	end

	function state.remove(player): boolean
		if not joined[player] then
			return false
		end

		joined[player] = nil
		return true
	end

	function state.contains(player): boolean
		return joined[player] == true
	end

	function state.get_players()
		local players = {}

		for player in joined do
			table.insert(players, player)
		end

		return players
	end

	function state.mask(): number
		generation += 1
		is_masking = true
		table.clear(joined)
		return generation
	end

	function state.release(expected_generation: number?): boolean
		if expected_generation ~= nil and expected_generation ~= generation then
			return false
		end

		is_masking = false
		return true
	end

	function state.is_masking(): boolean
		return is_masking
	end

	function state.is_current_generation(expected_generation: number): boolean
		return expected_generation == generation
	end

	return state
end

return player_relay_state
