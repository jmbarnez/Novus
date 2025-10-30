---@diagnostic disable: undefined-global
-- Skill Utilities - Functions for managing player skills and XP
-- Decouples skill management from UISystem

local ECS = require('src.ecs')
local LevelUtils = require('src.level_utils')

local SkillUtils = {}

-- Add skill experience and handle level ups
-- @param skillName string: The name of the skill ("mining", "salvaging", "combat", etc.)
-- @param xpGain number: Amount of experience to award
function SkillUtils.addSkillExperience(skillName, xpGain, playerId)
    -- Optional playerId: if provided, award to that entity's Skills component; otherwise award to first Player
    local targetId = playerId
    if not targetId then
        local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
        if #playerEntities == 0 then return false end
        targetId = playerEntities[1]
    end

    local skills = ECS.getComponent(targetId, "Skills")
    if not skills or not skills.skills[skillName] then return false end

    local skill = skills.skills[skillName]
    skill.experience = skill.experience + xpGain
    skill.totalXp = (skill.totalXp or 0) + xpGain

    -- Global level progression mirrors skill gains (scaled down slightly)
    local levelXp = math.max(1, math.floor(xpGain * 0.75))
    LevelUtils.addExperience(levelXp)

    -- Check for level up
    local leveledUp = false
    while skill.experience >= skill.requiredXp do
        skill.experience = skill.experience - skill.requiredXp
        skill.level = skill.level + 1
        skill.requiredXp = math.ceil(skill.requiredXp * 1.1)  -- 10% increase per level
        leveledUp = true
    end

    -- Build notification data
    local notifData = {
        level = skill.level,
        experience = skill.experience,
        requiredXp = skill.requiredXp,
        levelUp = leveledUp
    }
    local Notifications = require('src.ui.notifications')
    Notifications.addSkillNotification(skillName, xpGain, notifData)

    return leveledUp, notifData
end

return SkillUtils
