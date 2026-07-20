local player_relay_state = require("@layer/systems/default/Players/player_relay_state")

local alice = {}
local bob = {}
local charlie = {}
local state = player_relay_state.new({ alice })

assert(state.contains(alice), "initial players should be visible")

local first_generation = state.mask()
assert(#state.get_players() == 0, "masking should hide every player")
assert(not state.add(bob), "joins should be withheld while masking")

local second_generation = state.mask()
assert(not state.release(first_generation), "a stale release must not unmask a newer load")
assert(not state.add(bob), "a stale release must leave masking enabled")
assert(state.release(second_generation), "the current load should be releasable")

assert(state.add(alice), "release should allow the current player snapshot to be replayed")
assert(state.add(bob), "players who arrived while masked should be replayable")
assert(not state.add(bob), "duplicate engine events should not duplicate visibility state")
assert(state.contains(alice) and state.contains(bob), "replayed players should be queryable")

assert(state.remove(alice), "a visible player's removal should be relayed")
assert(not state.remove(alice), "a player's removal should only be relayed once")
assert(not state.contains(alice), "removed players should no longer be queryable")

assert(state.add(charlie), "joins should update visibility without requiring a signal subscriber")
assert(state.contains(charlie), "subscriber-independent joins should be queryable")

print("passed player relay state cases")
