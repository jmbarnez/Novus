---@diagnostic disable: undefined-global
-- Quest Utilities - Thin wrapper around QuestSystem progress helpers

local QuestSystem = require('src.systems.quest_system')

local QuestUtils = {}

function QuestUtils.updateMiningProgress()
    QuestSystem.updateMiningProgress()
end

function QuestUtils.updateCombatProgress()
    QuestSystem.updateCombatProgress()
end

function QuestUtils.updateSalvagingProgress()
    QuestSystem.updateSalvagingProgress()
end

return QuestUtils
