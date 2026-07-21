local native_var_defs = require("./native_var_defs")

local defs = native_var_defs.definitions

type Doc<T> = {
    tooltip: string,
    values: { [T]: string }
}

local docs: { [string]: Doc<unknown> } = {}

docs[defs.sv_vip_friends.id] = {
    tooltip = "Alters checks for your friends/'best friends'.",
    values = {
        everyone = "you're friends with everyone!",
        owner = "you're friends with the game's creator, and your normal friends!",
        nobody = "NOBODY is your friend.",
        default = "just keep your normal roblox friends list."
    }
}

docs[defs.sv_vip_group_presence.id] = {
    tooltip = "Alters checks for the groups you're in.",
    values = {
        all = "you're in ALL groups on roblox!",
        default = "you're just in your normal roblox groups.",
    }
}

docs[defs.sv_vip_group_rank.id] = {
    tooltip = "Alters checks for your rank in groups.",
    values = {
        owner = "you own the group!",
        default = "you're just your normal roblox rank in the group.",
    }
}

docs[defs.sv_vip_unlock_badges.id] = {
    tooltip = "Alters checks for badges you own.",
    values = {
        all = "you own ALL badges on roblox!",
        default = "you just own your normal roblox badges.",
    }
}

docs[defs.sv_timescale_run_service.id] = {
    tooltip = "Multiplies the value of `Stepped`/`RenderStepped` DeltaTime. This mainly affects projectiles.",
    values = {}
}

docs[defs.sv_timescale_wait.id] = {
    tooltip = "Yields all calls to `wait` and blocks `Stepped`/`RenderStepped`. This mainly affects game loop timers.",
    values = {}
}

return docs