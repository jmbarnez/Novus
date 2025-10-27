---@diagnostic disable: undefined-global
-- Level Utilities - centralizes player level progression and XP handling

local ECS = require('src.ecs')

local LevelUtils = {
    BASE_REQUIRED_XP = 200,
    GROWTH_RATE = 1.25
}

local function getPlayerLevelComponent()
    local players = ECS.getEntitiesWith({"Player", "Level"})
    if #players == 0 then
        return nil, nil
    end
    local playerId = players[1]
    return ECS.getComponent(playerId, "Level"), playerId
end

function LevelUtils.addExperience(xpGain)
    if not xpGain or xpGain <= 0 then
        return
    end

    local levelComp = getPlayerLevelComponent()
    if not levelComp then
        return
    end

    levelComp.experience = (levelComp.experience or 0) + xpGain
    levelComp.totalXp = (levelComp.totalXp or 0) + xpGain
    levelComp.requiredXp = levelComp.requiredXp or LevelUtils.BASE_REQUIRED_XP

    local leveledUp = false
    while levelComp.experience >= levelComp.requiredXp do
        levelComp.experience = levelComp.experience - levelComp.requiredXp
        levelComp.level = (levelComp.level or 1) + 1
        levelComp.requiredXp = math.ceil(levelComp.requiredXp * LevelUtils.GROWTH_RATE)
        leveledUp = true
    end

    if leveledUp then
        local Notifications = require('src.ui.notifications')
        if Notifications and Notifications.addLevelNotification then
            Notifications.addLevelNotification(levelComp.level)
        end
    end
end

function LevelUtils.getPlayerLevelData()
    local levelComp = getPlayerLevelComponent()
    if not levelComp then
        return nil
    end
    return {
        level = levelComp.level or 1,
        experience = levelComp.experience or 0,
        requiredXp = levelComp.requiredXp or LevelUtils.BASE_REQUIRED_XP,
        totalXp = levelComp.totalXp or 0
    }
end

return LevelUtils
