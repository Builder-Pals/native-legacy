local Players = game:GetService("Players")

--[[
	Combines multiple signal and data sources into one to reduce boilerplate code.

	local player_added = Composite
		.new()
		:listen(Players.PlayerAdded)
		:collect(Players.GetPlayers)
		:cleanup(Players.PlayerRemoving)

	Composite.listen(player_added, function(player)
		-- do stuff with player
	end)
]]
local Composite = {}

type FirstArgSignal<T> = RBXScriptSignal<T> | RBXScriptSignal<T, any> | RBXScriptSignal<T, any, any>

type BuilderData<T> = {
	pre_entries: { { object: T, method: (T) -> { any } } },
	pre_entry_objects: { T },
	signals: { FirstArgSignal<T> },
	cleanup_signals: { FirstArgSignal<T> },
}

type AnonBuilder = {
	listen: <T>(self: AnonBuilder, signal: FirstArgSignal<T>) -> Builder<T>,
	--[=[
		Fires the callback for each item in the array returned by this method.

		```luau
		Builder:collect(Players, Players.GetPlayers)
		```
	]=]
	collect: <T, Class>(self: AnonBuilder, object: Class, method: (instance: Class) -> { T }) -> Builder<T>,
	add: <T>(self: AnonBuilder, object: T?) -> Builder<T>,
	add_array: <Class, T>(self: AnonBuilder, objects: { T }?) -> Builder<T>,
	cleanup: <T>(self: AnonBuilder, signal: FirstArgSignal<T>) -> Builder<T>,
	data: BuilderData<any>,
	connect: <T>(builder: AnonBuilder, callback: any) -> (),
}

type Builder<T> = {
	listen: (self: Builder<T>, signal: FirstArgSignal<T>) -> Builder<T>,
	--[=[
		Fires the callback for each item in the array returned by this method.

		```luau
		Builder:collect(Players, Players.GetPlayers)
		```
	]=]
	collect: <Class>(self: Builder<T>, object: Class, method: (self: Class) -> { T }) -> Builder<T>,
	add: <Class>(self: Builder<T>, object: T?) -> Builder<T>,
	add_array: <Class>(self: Builder<T>, objects: { T }?) -> Builder<T>,
	cleanup: (self: Builder<T>, signal: FirstArgSignal<T>) -> Builder<T>,
	data: BuilderData<T>,
	--- **Note:** Connected functions must *explicitally* return nil, or a cleanup function.
	connect: (self: Builder<T>, Callback<T>) -> () -- 1
		& (self: Builder<T>, CallbackWithCleanup<T>) -> (),
}

type CallbackWithCleanup<T> = (T) -> () -> ()
type Callback<T> = (T) -> nil?
type SomeCallback<T> = Callback<T> | CallbackWithCleanup<T>

function Composite.connect<T>(builder: Builder<T>, callback: SomeCallback<T>)
	local cleanup_map: { [T]: () -> () } = {}

	local function process(x: T)
		print("processing", x)
		local cleanup = callback(x)

		if cleanup then
			cleanup_map[x] = cleanup
		end
	end

	for _, signal: RBXScriptSignal<T> in builder.data.signals do
		signal:Connect(process)
	end

	for _, signal: RBXScriptSignal<T> in builder.data.cleanup_signals do
		signal:Connect(function(x: T)
			local cleanup = cleanup_map[x]

			if cleanup then
				cleanup_map[x] = nil
				cleanup()
			end
		end)
	end

	for _, pre_entry in builder.data.pre_entries do
		pre_entry.method(pre_entry.object)
	end
end

-- Luau type function that removes the optional (?) from the type.
type function Unoptional(ty: type)
	-- T? = (T | nil) - they're just a union
	-- so we can unoptional something by removing nil from the union.
	local out = {}

	assert(ty.tag == "union", "Unoptional can only be used on union types")

	for _, value in ty:components() do
		if not value:is("nil") then
			table.insert(out, value)
		end
	end

	return types.unionof(unpack(out))
end

function Composite.from<T, X>(
	signal: FirstArgSignal<T> & FirstArgSignal<X>,
	add: { X } | { X? } | X | X?,
	remove_signal: FirstArgSignal<T>?
): Builder<X>
	local composite = Composite.new():listen(signal)

	if add then
		if type(add) == "table" then
			composite:add_array(add)
		else
			composite:add(add)
		end
	end

	if remove_signal then
		composite:listen(remove_signal)
	end

	return composite
end

function Composite.new(): AnonBuilder
	local pre_entries = {}
	local signals = {}
	local cleanup_signals = {}
	local pre_entry_objects: { any } = {}

	local builder = {
		data = {
			pre_entries = pre_entries,
			signals = signals,
			cleanup_signals = cleanup_signals,
			pre_entry_objects = pre_entry_objects,
		},
	} :: AnonBuilder

	function builder:connect(fn: SomeCallback<any>)
		Composite.connect(builder :: Builder<any>, fn)
	end

	function builder:add(object): any
		if object ~= nil then
			table.insert(pre_entry_objects, object)
		end

		return builder
	end

	function builder:add_array(objects)
		if objects == nil then
			return builder :: any
		end

		for _, object in objects do
			table.insert(pre_entry_objects, object)
		end

		return builder :: any
	end

	function builder:listen(signal: RBXScriptSignal)
		table.insert(signals, signal)
		return builder :: any
	end

	function builder:collect(object, method)
		table.insert(pre_entries, {
			object = object,
			method = method,
		})

		return builder :: any
	end

	function builder:cleanup(signal)
		table.insert(cleanup_signals, signal)
		return builder :: any
	end

	return builder
end

local common = {}

common.player_added =
	Composite.new():listen(Players.PlayerAdded):collect(Players, Players.GetPlayers):cleanup(Players.PlayerRemoving)

Composite.common = common

return Composite
