-- shout out to pizzaboxer again!
-- archive: github/pizzaboxer/rbxlinkedscripts

-- Source - https://stackoverflow.com/a/27455195
-- Posted by PersianGulf, modified by community. See post 'Timeline' for change history
-- Retrieved 2026-07-16, License - CC BY-SA 4.0
local function trim(str: string): string
	return str:match("^%s*(.-)%s*$") or ""
end

local LINKED_SOURCE_MAPPING = {
	["http://www.roblox.com/asset/?id=1014541"] = require("@layer/linked_sources/paintball_projectile"),
	["http://www.roblox.com/asset/?id=1014542"] = require("@layer/linked_sources/paintball_launcher"),
	["http://www.roblox.com/asset/?id=1014609"] = require("@layer/linked_sources/trowel_brick_cleanup"),
	["http://www.roblox.com/asset/?id=1014610"] = require("@layer/linked_sources/trowel_gui"),
	["http://www.roblox.com/asset/?id=1014611"] = require("@layer/linked_sources/trowel"),
	["http://www.roblox.com/asset/?id=1014616"] = require("@layer/linked_sources/time_bomb"),
	["http://www.roblox.com/asset/?id=1014617"] = require("@layer/linked_sources/time_bomb_gui"),
	["http://www.roblox.com/asset/?id=1014618"] = require("@layer/linked_sources/time_bomb_plant"),
	["http://www.roblox.com/asset/?id=1014631"] = require("@layer/linked_sources/superball_gui"),
	["http://www.roblox.com/asset/?id=1014632"] = require("@layer/linked_sources/superball"),
	["http://www.roblox.com/asset/?id=1014633"] = require("@layer/linked_sources/superball_launcher"),
	["http://www.roblox.com/asset/?id=1014650"] = require("@layer/linked_sources/slingshot_gui"),
	["http://www.roblox.com/asset/?id=1014651"] = require("@layer/linked_sources/slingshot"),
	["http://www.roblox.com/asset/?id=1014652"] = require("@layer/linked_sources/slingshot_projectile"),
	["http://www.roblox.com/asset/?id=1014653"] = require("@layer/linked_sources/rocket_launcher_gui"),
	["http://www.roblox.com/asset/?id=1014654"] = require("@layer/linked_sources/rocket_launcher"),
	["http://www.roblox.com/asset/?id=1014655"] = require("@layer/linked_sources/rocket_launcher_rocket"),
}

local function from_url(url: string)
    return trim(LINKED_SOURCE_MAPPING[url]):lower()
end

return {
    from_url = from_url,
}