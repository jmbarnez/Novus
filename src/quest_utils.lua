---@diagnostic disable: undefined-global
-- Quest Utilities - Quest progress tracking functions
-- Decouples quest progress updates from QuestSystem

local ECS = require('src.ecs')

local QuestUtils = {}

-- Update quest progress for mining
function QuestUtils.updateMiningProgress()
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
function QuestUtils.updateCombatProgress()
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

-- Update quest progress for salvaging
function QuestUtils.updateSalvagingProgress()
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed and quest.type == "salvaging" then
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

return QuestUtils
