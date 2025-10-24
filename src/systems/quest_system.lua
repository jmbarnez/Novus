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
            name = "Iron Harvest",
            description = "Mine %d iron ore from asteroids in the sector.",
            baseReward = 500,
            rewardPerUnit = 50,
            requirement = function() return math.random(5, 15) end
        },
        {
            name = "Stone Gathering",
            description = "Extract %d stone from the asteroid fields.",
            baseReward = 200,
            rewardPerUnit = 30,
            requirement = function() return math.random(8, 20) end
        }
    },
    combat = {
        {
            name = "Pirate Hunt",
            description = "Eliminate %d hostile ship%s in this sector.",
            baseReward = 800,
            rewardPerUnit = 150,
            requirement = function() return math.random(3, 8) end
        },
        {
            name = "Wreckage Recovery",
            description = "Salvage debris from %d destroyed ship%s.",
            baseReward = 600,
            rewardPerUnit = 100,
            requirement = function() return math.random(2, 6) end
        },
        {
            name = "Sector Patrol",
            description = "Scout the sector and eliminate any threats.",
            baseReward = 1200,
            rewardPerUnit = 0,
            requirement = function() return 1 end
        }
    },
    exploration = {
        {
            name = "Asteroid Survey",
            description = "Survey %d asteroid cluster%s this sector.",
            baseReward = 400,
            rewardPerUnit = 50,
            requirement = function() return math.random(2, 5) end
        },
        {
            name = "Deep Space Scan",
            description = "Map unexplored regions of the sector.",
            baseReward = 700,
            rewardPerUnit = 0,
            requirement = function() return 1 end
        },
        {
            name = "Resource Discovery",
            description = "Locate %d resource deposit%s and record their locations.",
            baseReward = 550,
            rewardPerUnit = 75,
            requirement = function() return math.random(3, 7) end
        }
    }
}

-- Generate a random quest from templates
local function generateQuest()
    local questTypes = {"mining", "combat", "exploration"}
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
    
    print(string.format("[QuestSystem] Generated 3 new quests for station %d", stationId))
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
            print(string.format("[QuestSystem] Quest accepted: %s", quest.title))
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
                        print(string.format("[QuestSystem] Mining progress: %d/%d", quest.requirements.current, quest.requirements.count))
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                            print(string.format("[QuestSystem] Quest completed: %s", quest.title))
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
                        print(string.format("[QuestSystem] Combat progress: %d/%d", quest.requirements.current, quest.requirements.count))
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                            print(string.format("[QuestSystem] Quest completed: %s", quest.title))
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
                        print(string.format("[QuestSystem] Exploration progress: %d/%d", quest.requirements.current, quest.requirements.count))
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                            print(string.format("[QuestSystem] Quest completed: %s", quest.title))
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
                    print(string.format("[QuestSystem] Quest reward claimed: %d credits", quest.reward))
                    
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

