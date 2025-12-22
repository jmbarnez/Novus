local Concord = require("lib.concord")
local Quests = require("game.quests")
local StationUI = require("game.hud.station_state")

local QuestSystem = Concord.system({
    -- We don't necessarily need to iterate over entities, just listen for events
})

function QuestSystem:init(world)
    self.world = world
end

-- Grant rewards for any newly completed quests
function QuestSystem:grantRewards(quests)
    local player = self.world:getResource("player")
    if not player then return end

    for _, quest in ipairs(quests) do
        -- Grant reward if quest just completed and hasn't been rewarded yet
        if quest.completed and not quest.rewarded and quest.reward then
            if player:has("credits") then
                player.credits.balance = player.credits.balance + quest.reward
            end
            quest.rewarded = true
        end
    end
end

-- Event: onAsteroidDestroyed(entity, x, y, radius)
function QuestSystem:onAsteroidDestroyed(entity, x, y, radius)
    local stationUi = self.world:getResource("station_ui")
    if not stationUi or not stationUi.quests then return end

    Quests.updateProgress(stationUi.quests, "destroy_asteroids", "asteroid", 1)
    self:grantRewards(stationUi.quests)
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
    self:grantRewards(stationUi.quests)
end

return QuestSystem
