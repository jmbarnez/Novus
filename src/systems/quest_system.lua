---@diagnostic disable: undefined-global
-- Quest System - Manages procedural quest generation and tracking

local ECS = require('src.ecs')
local Components = require('src.components')

local QuestSystem = {
    name = "QuestSystem",
    priority = 15
}

-- Quest templates for procedural generation
local questTemplates = {
    mining = {
        {
            name = "Mine Asteroids",
            description = "Mine %d asteroid%s for ore.",
            baseReward = 80,
            rewardPerUnit = 25,
            requirement = function() return math.random(2, 5) end
        }
    },
    salvaging = {
        {
            name = "Salvage Wrecks",
            description = "Salvage %d ship wreck%s in the sector.",
            baseReward = 100,
            rewardPerUnit = 30,
            requirement = function() return math.random(1, 3) end
        }
    },
    combat = {
        {
            name = "Destroy Red Scouts",
            description = "Destroy %d Red Scout%s.",
            baseReward = 120,
            rewardPerUnit = 40,
            requirement = function() return math.random(1, 4) end
        }
    }
}

-- Generate a random quest from templates
local function generateQuest()
    local questTypes = {"mining", "salvaging", "combat"}
    local questType = questTypes[math.random(#questTypes)]
    local templates = questTemplates[questType]
    local template = templates[math.random(#templates)]

    local requirement = template.requirement()
    local reward = template.baseReward + (template.rewardPerUnit * requirement)

    -- Format description with singular/plural
    local description = template.description
    if template.requirement then
        if requirement == 1 then
            description = description:gsub("%%d", tostring(requirement)):gsub("%%s", "")
        else
            description = description:gsub("%%d", tostring(requirement)):gsub("%%s", "s")
        end
    end

    local questId = "quest_" .. questType .. "_" .. math.random(1000, 9999)

    return Components.Quest(
        questId,
        template.name,
        description,
        questType,
        reward,
        {count = requirement, current = 0}
    )
end

-- Generate 3 quests for a station
local function generateQuestsForStation(stationId)
    local questBoard = ECS.getComponent(stationId, "QuestBoard")
    if not questBoard then return end
    
    questBoard.quests = {}
    for i = 1, 3 do
        table.insert(questBoard.quests, generateQuest())
    end
    
    questBoard.lastGenerationTime = love.timer.getTime()
end

-- Initialize quest board for a station if it doesn't have one
function QuestSystem.initQuestBoard(stationId)
    local questBoard = ECS.getComponent(stationId, "QuestBoard")
    if not questBoard then
        ECS.addComponent(stationId, "QuestBoard", Components.QuestBoard(stationId))
        generateQuestsForStation(stationId)
    end
end

-- Update quest system
function QuestSystem.update(dt)
    -- Find all stations with quest boards
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            local currentTime = love.timer.getTime()
            local timeSinceGeneration = currentTime - questBoard.lastGenerationTime
            
            -- Regenerate quests every 30 minutes
            if timeSinceGeneration >= questBoard.generationInterval then
                -- Only regenerate if player hasn't accepted any quests
                local hasAcceptedQuest = false
                for _, quest in ipairs(questBoard.quests) do
                    if quest.accepted then
                        hasAcceptedQuest = true
                        break
                    end
                end
                
                if not hasAcceptedQuest then
                    generateQuestsForStation(stationId)
                end
            end
        end
    end
end

-- Get quests for a station
function QuestSystem.getQuests(stationId)
    local questBoard = ECS.getComponent(stationId, "QuestBoard")
    if questBoard then
        return questBoard.quests
    end
    return {}
end

-- Accept a quest
function QuestSystem.acceptQuest(stationId, questId)
    local questBoard = ECS.getComponent(stationId, "QuestBoard")
    if not questBoard then return false end
    
    for _, quest in ipairs(questBoard.quests) do
        if quest.id == questId then
            quest.accepted = true
            quest.acceptedTime = love.timer.getTime()
            return true
        end
    end
    
    return false
end

-- Update quest progress for mining
function QuestSystem.updateMiningProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "mining" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end
end

-- Update quest progress for combat
function QuestSystem.updateCombatProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "combat" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end
end

-- Update quest progress for exploration
function QuestSystem.updateExplorationProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "exploration" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end
end

-- Turn in a completed quest and get reward
function QuestSystem.turnInQuest(stationId, questId)
    local questBoard = ECS.getComponent(stationId, "QuestBoard")
    if not questBoard then return false end
    
    for _, quest in ipairs(questBoard.quests) do
        if quest.id == questId and quest.completed then
            -- Give reward to player
            local players = ECS.getEntitiesWith({"Player", "Wallet"})
            if #players > 0 then
                local wallet = ECS.getComponent(players[1], "Wallet")
                if wallet then
                    wallet.credits = wallet.credits + quest.reward
                    
                    -- Remove quest from board
                    for i, q in ipairs(questBoard.quests) do
                        if q.id == questId then
                            table.remove(questBoard.quests, i)
                            break
                        end
                    end
                    
                    return true
                end
            end
        end
    end
    
    return false
end

return QuestSystem

