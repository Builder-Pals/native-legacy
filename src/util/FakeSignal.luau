--[=[
	Creates impostor RBXScriptSignals, which can be connected to multiple events at
	once under the hood, with support for middleware.
]=]

local sandbox = require("@layer/sandbox")
local new_symbol = require("@layer/util/new_symbol")
local patching = sandbox.patching

export type ProcessorFactory = (AnyFn) -> AnyFn
export type AnyFn = (...any) -> ...any

local SINK = new_symbol("FakeSignal Sink")

local connection_mt, signal_mt

local function sink_processor(callback: AnyFn)
	return function(arg1, ...)
		if arg1 == SINK then
			return
		end

		callback(arg1, ...)
	end
end

export type FakeConnectionContext = {
	signal: FakeSignalContext,
	original_callback: AnyFn,
	connections: { RBXScriptConnection },
}

export type FakeSignalContext = {
	signals: { RBXScriptSignal },
	processors: { ProcessorFactory },
	remote: BindableEvent?,
	connections: { [AnyFn]: FakeConnectionContext },
}

local function connection_disconnect(ctx: FakeConnectionContext)
	for _, connection in ctx.connections do
		connection:Disconnect()
	end

	ctx.signal.connections[ctx.original_callback] = nil
end

local function signal_disconnect(ctx: FakeSignalContext, callback: AnyFn)
	local match = ctx.connections[callback]

	if match then
		connection_disconnect(match)
	end
end

local function signal_gc(ctx: FakeSignalContext)
	for callback, listener in ctx.connections do
		local alive = false
		
		for _, connection in listener.connections do
			if connection.Connected then
				alive = true
				break
			end
		end
		
		if not alive then
			ctx.connections[callback] = nil
		end
	end
end

local function signal_connect(ctx: FakeSignalContext, callback)
	signal_gc(ctx)

	local fake_connection: FakeConnectionContext = {
		original_callback = callback,
		signal = ctx,
		connections = {},
	}

	-- connect to the real signals
	for index, event in ctx.signals do
		local fn = if ctx.processors[index] == sink_processor
			then sink_processor(callback)
			else sink_processor(ctx.processors[index](callback))

		table.insert(fake_connection.connections, event:Connect(fn))
	end

	setmetatable(fake_connection, connection_mt)
	ctx.connections[callback] = fake_connection

	return fake_connection
end

local function signal_wait(ctx: FakeSignalContext)
	local thread = coroutine.running()

	local connection = signal_connect(ctx, function(...)
		coroutine.resume(thread)
		coroutine.resume(thread, ...)
	end)

	coroutine.yield()
	connection_disconnect(connection)
	return coroutine.yield()
end

--- Binds a `FakeSignal` to an existing signal. If provided, the processor will be able to mutate
--- arguments before they reach any underlying callbacks.
local function signal_bind(ctx: FakeSignalContext, signal: RBXScriptSignal, processor: ProcessorFactory?)
	table.insert(ctx.signals, signal)
	table.insert(ctx.processors, processor or sink_processor)
end

local function signal_fire(ctx: FakeSignalContext, ...)
	if ctx.remote then
		ctx.remote:Fire(...)
		return
	end

	local bind = Instance.new("BindableEvent")
	signal_bind(ctx, bind.Event)
	ctx.remote = bind
	bind:Fire(...)
end

local function new_signal()
	local fake_signal: FakeSignalContext = {
		connections = {},
		processors = {},
		signals = {}
	}

	setmetatable(fake_signal, signal_mt)
	return fake_signal
end

local function new_processor(x: ProcessorFactory)
	return x
end

local function signal_wipe_connections(signal: FakeSignalContext)
	for _, connection in signal.connections do
		connection_disconnect(connection)
	end

	table.clear(signal.connections)
end

connection_mt = {
	Disconnect = connection_disconnect,
	disconnect = connection_disconnect,
	Wait = signal_wait,
	wait = signal_wait,
	[patching.symbols.FAKE_TYPE] = "userdata",
	[patching.symbols.FAKE_TYPEOF] = "RBXScriptConnection",
}

connection_mt.__index = connection_mt

signal_mt = {
	connect = signal_connect,
	Connect = signal_connect,
	disconnect = signal_disconnect, -- only available in camelCase!
	[patching.symbols.FAKE_TYPE] = "userdata",
	[patching.symbols.FAKE_TYPEOF] = "RBXScriptSignal",
}

signal_mt.__index = signal_mt

return {
	SINK = SINK,
	new = new_signal,
	bind = signal_bind,
	fire = signal_fire,
	new_processor = new_processor,
	wipe_connections = signal_wipe_connections,
}
