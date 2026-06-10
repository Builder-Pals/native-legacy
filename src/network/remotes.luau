local global_remote_events = require("./global_remote_events")
local new_remote_index = require("./new_remote_index")
local remote_ids = require("./remote_ids")

local remotes = {}

remotes.reliable = new_remote_index(global_remote_events.remote_event)
remotes.unreliable = new_remote_index((global_remote_events.unreliable_remote_event :: unknown) :: RemoteEvent)
remotes.ids = remote_ids

return remotes