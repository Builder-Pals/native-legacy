--[=[
	## plz

	my super-focused ui library, plz.
]=]
local plz = {}

const RunService = game:GetService("RunService")
const STEP_SIGNAL = RunService:IsServer() and RunService.Heartbeat or RunService.RenderStepped

local evy = {}

export type EvyContext = {
	-- { [Instance]: { [event_name: string]: { pack() } } }
	mapping: { [Instance]: { [string]: { any } } },
	-- { [Instance]: { [event_name: string]: RBXScriptConnection } }
	connections: { [Instance]: { [string]: RBXScriptConnection } },
	-- { [Instance]: { [event_name: string]: true } }
	accessed_this_frame: { [Instance]: { [string]: true } },
	-- cleared every frame
	listeners: { [Instance]: { [string]: { (...any) -> () } } }
}

do
	function evy.context()
		local new_context: EvyContext = {
			mapping = {},
			connections = {},
			accessed_this_frame = {},
			listeners = {}
		}

		return new_context
	end

	function evy.touch(ctx: EvyContext, instance: Instance, event: string)
		ctx.accessed_this_frame[instance] = ctx.accessed_this_frame[instance] or {}
		ctx.accessed_this_frame[instance][event] = true

		ctx.mapping[instance] = ctx.mapping[instance] or {}

		if ctx.mapping[instance][event] then
			return
		end

		ctx.mapping[instance][event] = ctx.mapping[instance][event] or {} 
		ctx.connections[instance] = ctx.connections[instance] or {}
		ctx.listeners[instance] = ctx.listeners[instance] or {}
		ctx.listeners[instance][event] = ctx.listeners[instance][event] or {}

		evy.collect(ctx, instance, event)
	end

	function evy.collect(ctx: EvyContext, instance: Instance, event: string)
		if ctx.connections[instance][event] then
			return -- don't register twice
		end
		
		local signal = (instance :: Instance & { [string]: unknown })[event]
		assert(typeof(signal) == "RBXScriptSignal")

		local packs = ctx.mapping[instance][event]
		--print(`connecting to {instance}.{event}`)

		ctx.connections[instance][event] = (signal::any):Connect(function(...)
			table.insert(packs, table.pack(...))
		end)
	end

	function evy.add_listener(ctx: EvyContext, instance: Instance, event: string, callback: (...any) -> ())
		table.insert(ctx.listeners[instance][event], callback)
	end

	function evy.flush(ctx: EvyContext)
		for instance, event_pack_map in ctx.mapping do
			local access_grants = ctx.accessed_this_frame[instance]

			if not next(access_grants) then
				ctx.mapping[instance] = nil
				ctx.listeners[instance] = nil
				
				for _, connection in ctx.connections[instance] do
					--print(`disconnecting an event from {instance}`)
					connection:Disconnect()
				end

				ctx.connections[instance] = nil
				continue
			end

			table.clear(ctx.accessed_this_frame[instance])

			-- future: we could clean-up non-accessed keys here too, but the use-case is narrow.

			for event_name, packs in event_pack_map do
				for _, listener in ctx.listeners[instance][event_name] do
					for _, pack in packs do
						listener(table.unpack(pack, pack.n))
					end
				end

				table.clear(ctx.listeners[instance][event_name])
				table.clear(packs)
			end
		end
	end
end

local templates: { Instance } = {}
local pool: { [number]: Instance } = {}
local changes: { [number]: { [string]: { any } } } = {}

const CHUNK_SIZE = 10000
local latest_allocation = 0

type Allocation<T = any> = { _T: T }
type Unpack<T> = index<T, "_T">

type EventKey<T...> = { _is_event_key: true, _listener: (T...) -> () }

export type Pen = {
	render: (self: Pen) -> number,
	node: <T>(self: Pen, allocation: Allocation<T>) -> Node<T>
}

export type Node<T=Instance, A...=...unknown> = T & {
	_allocation: Allocation<any>,
} & {
	[EventKey<A...>]: (A...) -> ()
}

export type PenCtx = {
    last_changes: { [number]: { [string]: true } },
	queue: { Node },
	dirty: { [Instance & {}]: number },
	references: { [Node]: number },
	free_elements: {Node},
	event_context: EvyContext
}

local pen = {}
pen.__index = pen

local NULL = newproxy(true)
getmetatable(NULL).__tostring = function()
	return "NULL"
end

local function nullable<T>(x: T): T?
	return if x == nil then NULL else x
end

local function unpack_nullable<T>(x: T): T?
	return if x == NULL then nil else x
end

local function get_id(allocation: Allocation<any>, offset: number)
    return allocation :: Unpack<Allocation> + offset
end

local function allocation_from_id(id: number)
	return id - id % CHUNK_SIZE
end

local function get_instance(allocation: Allocation<any>, offset: number): Instance & {}
	assert(offset < CHUNK_SIZE, `Offset > CHUNK_SIZE ({CHUNK_SIZE})`)
	local id = get_id(allocation, offset)
	local match = pool[id]

	if not match then
		local new = Instance.fromExisting(templates[allocation :: Unpack<Allocation>])
		pool[id] = new
		return new
	end

	return match
end

local function get_defaults_entry(allocation: Allocation<any> | number)
	local id = allocation :: Unpack<Allocation>
	local match = changes[id]

	if not match then
		changes[id] = {}
		return changes[id]
	end

	return match
end

function pen.node<T>(ctx: PenCtx, allocation: Allocation<T>, hook): Node<T>
	local element = table.remove(ctx.free_elements) or {} :: Node<T>
 	element._allocation = allocation
	table.insert(ctx.queue, element)
	ctx.references[element] = #ctx.queue
	return element
end

function pen.render(ctx: PenCtx)
	local updates = 0
	local updated = {}

	for offset, element in ctx.queue do
		local id = get_id(element._allocation, offset)
		local instance = get_instance(element._allocation, offset)
		local defaults = get_defaults_entry(element._allocation)
        local last = ctx.last_changes[id] or {} :: keyof<index<PenCtx, "last_changes">>

		for key, value in element :: Node<any> do
			if key == "_allocation" then
				continue
			end

			if value == unpack_nullable(last[key]) then
				-- save the roblox api c boundary trip
				continue
			end

			-- this means that all tables are treated as references.
			-- that's OK, because the user should never be adding a table to
			-- a node otherwise
			if typeof(value) == "table" then
                local reference_offset = ctx.references[value]
                assert(reference_offset)
				assert(value._allocation, `missing allocation! {key} {reference_offset}`)

				if not defaults[key] then
					defaults[key] = nullable(instance[key])
					--print(`learnt a new default for {key}`, defaults[key])
				end

				local resolution = get_instance(value._allocation, reference_offset)

				if last[key] ~= resolution then
					instance[key] = resolution
					last[key] = resolution
					updates += 1
				end
			elseif typeof(value) == "function" then
				evy.touch(ctx.event_context, instance, key)
				evy.add_listener(ctx.event_context, instance, key, value)
				continue
            else
				if not defaults[key] then
					defaults[key] = nullable(instance[key])
					--print(`learnt a new default for {key}`, defaults[key])
				end

                instance[key] = value
				last[key] = nullable(value)
				updates += 1
			end
		end

		assert(id)
		ctx.dirty[instance] = id :: Unpack<Allocation>
		updated[instance] = true

        for key, value in last do
			if (element :: Node<unknown> & {})[key] == nil and defaults[key] ~= nil then
				instance[key] = unpack_nullable(defaults[key])
				last[key] = nil
			end
        end

        ctx.last_changes[id] = last
	end

	for instance, id in ctx.dirty do
		local allocation = allocation_from_id(id)

		if updated[instance] == nil then
			-- restore all defaults
			for key, value in get_defaults_entry(allocation) do
				instance[key] = unpack_nullable(value)
			end

			ctx.dirty[instance] = nil
			ctx.last_changes[id] = nil
		end
	end

	for index = 1, #ctx.queue do
		local element = ctx.queue[index]
		table.clear(element)
		table.insert(ctx.free_elements, element)
	end

	table.clear(ctx.queue)
	table.clear(ctx.references)

	evy.flush(ctx.event_context)

	return updates
end

assert(allocation_from_id(CHUNK_SIZE) == CHUNK_SIZE)
assert(allocation_from_id(CHUNK_SIZE * 2) == CHUNK_SIZE * 2)
assert(allocation_from_id((CHUNK_SIZE * 2) + math.floor(CHUNK_SIZE / 2)) == CHUNK_SIZE * 2)

function plz.pen()
    local ctx: PenCtx = {
        last_changes = {},
        queue = {},
		dirty = {},
		references = {},
		free_elements = table.create(500) :: index<PenCtx, "free_elements">,
		event_context = evy.context(),
    }

    return setmetatable(ctx, pen) :: Pen
end

--[=[
	Creates a spot for the provided Instance in the pool.
]=]
function plz.allocate<T>(instance: T & Instance)
	latest_allocation += CHUNK_SIZE
	templates[latest_allocation] = instance
	return (latest_allocation :: any) :: Allocation<T>
end

function plz.event<T...>(node: Node, key: RBXScriptSignal<T...>, fn: (T...) -> ())
	local s = if typeof(key) == "string" then key else tostring(key):sub(8)
	node[s] = fn
end

function plz.loop(pen: Pen, renderer: (delta_time: number, updates: number) -> (), loop)
	local last_updates = 0

	local connection = STEP_SIGNAL:Connect(function(delta_time)
		renderer(delta_time, last_updates)
		last_updates = pen:render()
	end)
	
	return function()
		connection:Disconnect()
	end
end

return plz
