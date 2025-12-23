--- Quest Generation and Tracking
--- Procedurally generates quests based on world seed

local Items = require("game.items")

local Quests = {}

local QUEST_TYPES = {
    {
        type = "collect_resource",
        generateDescription = function(target, amount, itemName)
            return string.format("Collect %d %s", amount, itemName)
        end,
    },
    {
        type = "destroy_asteroids",
        generateDescription = function(target, amount)
            return string.format("Destroy %d asteroids", amount)
        end,
    },
}

-- Get list of collectible item IDs
local function getCollectibleItems()
    local items = {}
    for id, _ in pairs(Items.all()) do
        table.insert(items, id)
    end
    return items
end

-- Generate procedural quests based on seed
function Quests.generate(seed, count)
    count = count or 5
    local rng = love.math.newRandomGenerator(seed)
    local quests = {}
    local collectibles = getCollectibleItems()

    for i = 1, count do
        local questType = rng:random(1, 2)
        local quest = {
            id = i,
            accepted = false,
            completed = false,
            rewarded = false,
            current = 0,
            turnInRequired = true,
        }

        if questType == 1 and #collectibles > 0 then
            -- Collect resource quest
            local itemId = collectibles[rng:random(1, #collectibles)]
            local itemDef = Items.get(itemId)
            local amount = rng:random(3, 15) * 5
            quest.type = "collect_resource"
            quest.target = itemId
            quest.amount = amount
            quest.description = string.format("Collect %d %s", amount, itemDef and itemDef.name or itemId)
            quest.reward = amount * (itemDef and 2 or 10)
        else
            -- Destroy asteroids quest
            local amount = rng:random(3, 10)
            quest.type = "destroy_asteroids"
            quest.target = "asteroid"
            quest.amount = amount
            quest.description = string.format("Destroy %d asteroids", amount)
            quest.reward = amount * 25
        end

        table.insert(quests, quest)
    end

    return quests
end

-- Accept a quest
function Quests.accept(quests, questId)
    for _, quest in ipairs(quests) do
        if quest.id == questId and not quest.accepted then
            quest.accepted = true
            return true
        end
    end
    return false
end

-- Check if quest is complete (progress only)
function Quests.checkCompletion(quest)
    if quest.accepted and quest.current >= quest.amount then
        quest.completed = true
        return true
    end
    return false
end

-- Update quest progress (called when player does relevant action)
function Quests.updateProgress(quests, questType, target, amount)
    amount = amount or 1
    for _, quest in ipairs(quests) do
        if quest.accepted and not quest.completed and quest.type == questType then
            if quest.type == "destroy_asteroids" or quest.target == target then
                quest.current = quest.current + amount
                Quests.checkCompletion(quest)
            end
        end
    end
end

-- Turn in a completed quest to grant rewards
-- @return boolean success, string message
function Quests.turnIn(quests, questId, player)
    for _, quest in ipairs(quests) do
        if quest.id == questId then
            if not quest.accepted then
                return false, "Quest not accepted"
            end
            if not quest.completed then
                return false, "Quest not complete"
            end
            if quest.rewarded then
                return false, "Already turned in"
            end

            if player and player:has("credits") and quest.reward then
                player.credits.balance = player.credits.balance + quest.reward
            end
            quest.rewarded = true
            return true, "Quest turned in"
        end
    end
    return false, "Quest not found"
end

return Quests
