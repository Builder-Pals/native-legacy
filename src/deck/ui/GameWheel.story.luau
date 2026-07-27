local plz = require("@layer/plz")
local game_catalog = require("../data/game_catalog")
local GameWheel = require("./GameWheel")

local function get_game_thumbnail(id: number): string
    const W = 768
    const H = 432
    return `rbxthumb://type=GameThumbnail&id={id}&w={W}&h={H}`
end

const GAMES = table.clone(game_catalog.all)

local base_games = table.clone(GAMES)
    
for i = 1, 8 do
    for _, game in base_games do
        table.insert(GAMES, table.clone(game))
    end
end

return function(parent: Frame)
    local pen = plz:pen()
    local state
    
    local function render(delta_time)
        local props = {
            delta_time = delta_time,
            absolute_size = parent.AbsoluteSize,
            games = GAMES
        }

        local wheel
        wheel, state = GameWheel(pen, props, state)
        wheel.Parent = parent
    end

    return plz.loop(pen, render)
end