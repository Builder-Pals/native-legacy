-- shout out to pizzaboxer again!
-- archive: github/pizzaboxer/rbxlinkedscripts

-- Source - https://stackoverflow.com/a/27455195
-- Posted by PersianGulf, modified by community. See post 'Timeline' for change history
-- Retrieved 2026-07-16, License - CC BY-SA 4.0
local function trim(str: string): string
	return str:match("^%s*(.-)%s*$") or ""
end

local LINKED_SOURCE_MAPPING = {
	["http://www.roblox.com/asset/?id=1014541"] = require("@self/paintball_projectile"),
	["http://www.roblox.com/asset/?id=1014542"] = require("@self/paintball_launcher"),
	["http://www.roblox.com/asset/?id=1014609"] = require("@self/trowel_brick_cleanup"),
	["http://www.roblox.com/asset/?id=1014610"] = require("@self/trowel_gui"),
	["http://www.roblox.com/asset/?id=1014611"] = require("@self/trowel"),
	["http://www.roblox.com/asset/?id=1014616"] = require("@self/time_bomb"),
	["http://www.roblox.com/asset/?id=1014617"] = require("@self/time_bomb_gui"),
	["http://www.roblox.com/asset/?id=1014618"] = require("@self/time_bomb_plant"),
	["http://www.roblox.com/asset/?id=1014631"] = require("@self/superball_gui"),
	["http://www.roblox.com/asset/?id=1014632"] = require("@self/superball"),
	["http://www.roblox.com/asset/?id=1014633"] = require("@self/superball_launcher"),
	["http://www.roblox.com/asset/?id=1014650"] = require("@self/slingshot_gui"),
	["http://www.roblox.com/asset/?id=1014651"] = require("@self/slingshot"),
	["http://www.roblox.com/asset/?id=1014652"] = require("@self/slingshot_projectile"),
	["http://www.roblox.com/asset/?id=1014653"] = require("@self/rocket_launcher_gui"),
	["http://www.roblox.com/asset/?id=1014654"] = require("@self/rocket_launcher"),
	["http://www.roblox.com/asset/?id=1014655"] = require("@self/rocket_launcher_rocket"),
	-- fun fact - this one still loads in 2026 for some reason!
	["http://www.roblox.com/asset/?id=13326026"] = require("@self/badge_awarder")
}

local function from_url(url: string)
    return trim(LINKED_SOURCE_MAPPING[url]):lower()
end

return {
    from_url = from_url,
}