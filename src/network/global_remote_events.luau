local RunService = game:GetService("RunService")

local global_remote_events = {}

if RunService:IsServer() or RunService:IsRunning() == false then
    global_remote_events.remote_event = Instance.new("RemoteEvent")
    global_remote_events.remote_event.Archivable = false
    global_remote_events.remote_event.Parent = script

    global_remote_events.unreliable_remote_event = Instance.new("UnreliableRemoteEvent")
    global_remote_events.unreliable_remote_event.Archivable = false
    global_remote_events.unreliable_remote_event.Parent = script
else
    global_remote_events.remote_event = script:WaitForChild("RemoteEvent") :: RemoteEvent
    global_remote_events.unreliable_remote_event = script:WaitForChild("UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

return global_remote_events