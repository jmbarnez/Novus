---@diagnostic disable: undefined-global
local Components = {}

-- Quest component - Represents a single quest
-- @field id string: Unique quest identifier
-- @field title string: Quest title
-- @field description string: Quest description
-- @field type string: Quest type ("mining", "combat", "exploration", "delivery")
-- @field reward number: Credit reward amount
-- @field accepted boolean: Whether the player has accepted this quest
-- @field completed boolean: Whether the quest is completed
-- @field requirements table: Quest-specific requirements (optional)
Components.Quest = function(id, title, description, questType, reward, requirements)
    return {
        id = id,
        title = title or "Unknown Quest",
        description = description or "No description available.",
        type = questType or "exploration",
        reward = reward or 100,
        accepted = false,
        completed = false,
        requirements = requirements or {},
        acceptedTime = nil
    }
end

-- QuestBoard component - Manages quests for a station
-- @field stationId number: Entity ID of the station
-- @field quests table: Array of active quests
-- @field lastGenerationTime number: When quests were last generated
-- @field generationInterval number: How often to regenerate quests (in seconds)
Components.QuestBoard = function(stationId)
    return {
        stationId = stationId,
        quests = {},
        lastGenerationTime = love.timer.getTime(),
        generationInterval = 1800 -- 30 minutes
    }
end

return Components

