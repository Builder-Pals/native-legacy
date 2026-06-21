export type ServerSends<T...> = string

local current_id = 0

local function next_id<T...>(): ServerSends<T...>
	current_id += 1
	return tostring(current_id)
end

local remote_ids = {
	unreliable = {
		mouse = {
			update = next_id()
		},

		target_point = {
			update = next_id(),
			tool_activate = next_id()
		},

		defiltering = {
			send_properties = next_id(),
		},
	},

	reliable = {
		console = {
			load_place = next_id(),
		},

		hopperbin = {
			select = next_id(),
			deselect = next_id(),
		},

		instance_pool = {
			expand = next_id(),
		},

		defiltering = {
			send_properties = next_id(),
			add_debris = next_id(),
		},
	},
}

return remote_ids
