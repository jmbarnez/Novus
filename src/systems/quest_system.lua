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
            requirement = function() return math.random(1, 4) end,
            enemyType = "red_scout"
        }
    }
}

local questStateVersion = 0

local function bumpQuestVersion()
    questStateVersion = questStateVersion + 1
end

local mainQuest

local function ensureMainQuest()
    if mainQuest then
        return mainQuest
    end

    mainQuest = Components.Quest(
        "main_repair_warpgate",
        "Restore the Warpgate",
        "The sector's primary warpgate is offline. Gather the necessary resources and bring it back online to reopen long-range travel.",
        "story",
        10000,
        {
            count = 1,
            current = 0,
            objective = "Repair the central warpgate."
        }
    )
    mainQuest.accepted = true
    mainQuest.isMainStory = true
    mainQuest.acceptedTime = love.timer.getTime()

    bumpQuestVersion()
    return mainQuest
end

local function grantMainQuestReward()
    local quest = ensureMainQuest()
    if quest.rewardGranted then
        return
    end

    local players = ECS.getEntitiesWith({"Player", "Wallet"})
    if #players > 0 then
        local wallet = ECS.getComponent(players[1], "Wallet")
        if wallet then
            wallet.credits = wallet.credits + quest.reward
        end
    end

    quest.rewardGranted = true

    local Notifications = require('src.ui.notifications')
    if Notifications and Notifications.add then
        Notifications.add({
            type = 'quest',
            text = string.format("Main quest complete! +%d credits", quest.reward),
            timer = 5.0
        })
    end
end

local function completeMainQuest()
    local quest = ensureMainQuest()
    if quest.completed then
        return
    end

    quest.requirements.current = quest.requirements.count
    quest.completed = true
    quest.completedTime = love.timer.getTime()

    grantMainQuestReward()
    bumpQuestVersion()
end

local function checkMainQuestProgress()
    local quest = ensureMainQuest()
    if not quest.accepted or quest.completed then
        return
    end

    local gateId = quest.requirements.gateId
    if gateId then
        local gate = ECS.getComponent(gateId, "WarpGate")
        if gate and gate.active then
            completeMainQuest()
        end
    end
end

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

    local requirements = {count = requirement, current = 0}
    -- Add enemy type for combat quests
    if questType == "combat" and template.enemyType then
        requirements.enemyType = template.enemyType
    end

    return Components.Quest(
        questId,
        template.name,
        description,
        questType,
        reward,
        requirements
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
    bumpQuestVersion()
end

-- Initialize quest board for a station if it doesn't have one
function QuestSystem.initQuestBoard(stationId)
    ensureMainQuest()
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

    checkMainQuestProgress()
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
            bumpQuestVersion()
            return true
        end
    end
    
    return false
end

-- Update quest progress for mining
function QuestSystem.updateMiningProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    local progressUpdated = false
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "mining" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        progressUpdated = true
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end

    if progressUpdated then
        bumpQuestVersion()
    end
end

-- Update quest progress for combat
function QuestSystem.updateCombatProgress(enemyType)
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    local progressUpdated = false
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "combat" then
                    -- Only update quests that match the specific enemy type
                    if not enemyType or not quest.requirements or quest.requirements.enemyType == enemyType then
                        if quest.requirements and quest.requirements.current then
                            quest.requirements.current = quest.requirements.current + 1
                            progressUpdated = true
                            
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

    if progressUpdated then
        bumpQuestVersion()
    end
end

-- Update quest progress for salvaging
function QuestSystem.updateSalvagingProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    local progressUpdated = false

    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "salvaging" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        progressUpdated = true

                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end

    if progressUpdated then
        bumpQuestVersion()
    end
end

-- Update quest progress for exploration
function QuestSystem.updateExplorationProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    local progressUpdated = false
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "exploration" then
                    if quest.requirements and quest.requirements.current then
                        quest.requirements.current = quest.requirements.current + 1
                        progressUpdated = true
                        
                        -- Check completion
                        if quest.requirements.current >= quest.requirements.count then
                            quest.completed = true
                        end
                    end
                end
            end
        end
    end

    if progressUpdated then
        bumpQuestVersion()
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
                    bumpQuestVersion()
                    
                    return true
                end
            end
        end
    end
    
    return false
end

function QuestSystem.getActiveQuests()
    local active = {}
    local quest = ensureMainQuest()
    if quest.accepted and not quest.completed then
        table.insert(active, quest)
    end

    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, boardQuest in ipairs(questBoard.quests) do
                if boardQuest.accepted and not boardQuest.completed then
                    table.insert(active, boardQuest)
                end
            end
        end
    end

    return active
end

function QuestSystem.getMainQuest()
    return ensureMainQuest()
end

function QuestSystem.registerMainQuestTarget(gateId)
    local quest = ensureMainQuest()
    if quest.requirements.gateId ~= gateId then
        quest.requirements.gateId = gateId
        bumpQuestVersion()
    end
end

function QuestSystem.onWarpGateRepaired(gateId)
    local quest = ensureMainQuest()
    if not quest.requirements.gateId then
        quest.requirements.gateId = gateId
    end

    if quest.completed then
        return
    end

    if quest.requirements.gateId == gateId then
        completeMainQuest()
    end
end

function QuestSystem.getQuestStateVersion()
    return questStateVersion
end

return QuestSystem

