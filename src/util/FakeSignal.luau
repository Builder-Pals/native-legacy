--[=[
	Emulates RBXScriptSignals with the ability to fire events from luau.
]=]

local sandbox = require("@layer/sandbox")
local new_symbol = require("@layer/util/new_symbol")
local patching = sandbox.patching

local SINK = new_symbol("FakeSignal Sink")

type Wire = {
	signal: RBXScriptSignal,
	middleware: (...any) -> ...any,
	connection: RBXScriptConnection?,
}

type WireLifecycle = {
	start: (self: FakeSignal) -> (),
	stop: (self: FakeSignal) -> (),
}

export type FakeSignal = {
	_listeners: { (...any) -> () },
	wire: Wire?,
	wire_lifecycle: WireLifecycle?,
}

export type FakeConnection = {
	_signal: FakeSignal,
	_callback: () -> (),
	connected: boolean,
	Connected: boolean,
}

export type SignalContext = {
	fire: (...any) -> (),
	signal: FakeSignal,
}

local function signal_fire(self: FakeSignal, ...)
	for _, listener in pairs(self._listeners) do
		-- note: signals are now deferred by default on roblox, but they weren't before.
		-- see Workspace.SignalBehaviour
		task.defer(listener, ...)
	end
end

local function signal_stop_wire(self: FakeSignal)
	if self.wire == nil or self.wire.connection == nil then
		return
	end

	self.wire.connection:Disconnect()

	if self.wire_lifecycle then
		self.wire_lifecycle.stop(self)
	end
end

--- Starts listening to the wired RBXScriptSignal (if present).
local function signal_start_wire(self: FakeSignal)
	if self.wire == nil or #self._listeners == 0 or self.wire.connection then
		return
	end

	if self.wire_lifecycle then
		self.wire_lifecycle.start(self)
	end

	local function and_then(first_arg, ...)
		if first_arg == SINK then
			return
		end

		if #self._listeners == 0 then
			signal_stop_wire(self)
		end

		return signal_fire(self, first_arg, ...)
	end

	self.wire.connection = self.wire.signal:Connect(function(...)
		and_then(self.wire.middleware(...))
	end)
end

local function signal_clear_listeners(self: FakeSignal)
	table.clear(self._listeners)
	signal_stop_wire(self)
end

local function signal_connect(self: FakeSignal, callback)
	assert(typeof(callback) == "function")
	table.insert(self._listeners, callback)
	signal_start_wire(self)
end

-- this method is deprecated and throws an error in modern roblox
local function signal_disconnect(self: FakeSignal, callback)
	for index, listener in self._listeners do
		if listener == callback then
			table.remove(self._listeners, index)
			break
		end
	end

	if #self._listeners == 0 then
		signal_stop_wire(self)
	end
end

local function connection_disconnect(self: FakeConnection)
	local index = table.find(self._signal._listeners, self._callback)

	if index then
		table.remove(self._signal._listeners, index)
	end

	self.connected = false
	self.Connected = false
end

local function signal_wait(self: FakeSignal)
	local thread: thread

	local function callback(...)
		coroutine.resume(thread, ...)
	end

	table.insert(self._listeners, callback)
	thread = coroutine.running()
	return coroutine.yield()
end

local function signal_wire(self: FakeSignal, signal: RBXScriptSignal, middleware)
	if self.wire and self.wire.connection then
		self.wire.connection:Disconnect()
	end

	self.wire = {
		signal = signal,
		middleware = middleware,
		connection = nil,
	}

	if #self._listeners > 0 then
		signal_start_wire(self)
	end
end

local function signal_wire_destroy(self: FakeSignal)
	signal_stop_wire(self)
	self.wire = nil
	self.wire_lifecycle = nil
end

local connection = {
	Disconnect = connection_disconnect,
	disconnect = connection_disconnect,
	Wait = signal_wait,
	wait = signal_wait,
	[patching.symbols.FAKE_TYPE] = "userdata",
	[patching.symbols.FAKE_TYPEOF] = "RBXScriptConnection",
}

connection.__index = connection

local signal = {
	connect = signal_connect,
	Connect = signal_connect,
	disconnect = signal_disconnect, -- only available in camelCase!
	[patching.symbols.FAKE_TYPE] = "userdata",
	[patching.symbols.FAKE_TYPEOF] = "RBXScriptSignal",
}

signal.__index = signal

local function new()
	local my_signal = setmetatable({
		_listeners = setmetatable({}, { __mode = "v" }),
	}, signal) :: FakeSignal

	return {
		fire = function(...)
			signal_fire(my_signal, ...)
		end,

		signal = my_signal,
	}
end

local function wire_lifecycle(self: FakeSignal, start, stop)
	self.wire_lifecycle = { start = start, stop = stop }
end

return {
	new = new,
	wire = signal_wire,
	wire_lifecycle = wire_lifecycle,
	destroy_wire = signal_wire_destroy,
	fire = signal_fire,
	clear_listeners = signal_clear_listeners,
	SINK = SINK,
}
