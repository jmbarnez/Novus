local Concord = require("lib.concord")
local Quests = require("game.quests")
local StationUI = require("game.station_ui")

local QuestSystem = Concord.system({
    -- We don't necessarily need to iterate over entities, just listen for events
})

function QuestSystem:init(world)
    self.world = world
end

-- Event: onAsteroidDestroyed(entity, x, y, radius)
function QuestSystem:onAsteroidDestroyed(entity, x, y, radius)
    local stationUi = self.world:getResource("station_ui")
    if not stationUi or not stationUi.quests then return end

    Quests.updateProgress(stationUi.quests, "destroy_asteroids", "asteroid", 1)
end

-- Event: onItemCollected(ship, itemId, amount)
function QuestSystem:onItemCollected(ship, itemId, amount)
    -- Only track player collections
    local player = self.world:getResource("player")
    if not player or not player.pilot or player.pilot.ship ~= ship then
        return
    end

    local stationUi = self.world:getResource("station_ui")
    if not stationUi or not stationUi.quests then return end

    Quests.updateProgress(stationUi.quests, "collect_resource", itemId, amount)
end

return QuestSystem
