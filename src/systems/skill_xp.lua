---@diagnostic disable: undefined-global
-- Skill XP System - Universal utility for calculating and awarding skill experience
-- Provides consistent experience scaling across all skills

local ECS = require('src.ecs')
local SkillUtils = require('src.skill_utils')

local SkillXP = {}

-- Configuration for each skill's XP rewards
local SKILL_CONFIG = {
    mining = {
        baseXp = 5,        -- Base XP for destroying an asteroid
        scalePerLevel = 1  -- XP bonus per level
    },
    salvaging = {
        baseXp = 5,        -- Base XP for destroying a wreckage
        scalePerLevel = 2  -- XP bonus per level
    },
    combat = {
        baseXp = 10,       -- Base XP for destroying an enemy
        scalePerLevel = 2  -- XP bonus per level
    }
}

-- Get the XP gain for a skill based on player's current level
-- @param skillName string: The name of the skill ("mining", "salvaging", "combat", etc.)
-- @return number: The amount of XP to award
function SkillXP.getXpGain(skillName)
    local config = SKILL_CONFIG[skillName]
    if not config then
        return 0  -- Unknown skill
    end
    
    -- Get player's skill level
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then
        return config.baseXp  -- No player, return base XP
    end
    
    local skills = ECS.getComponent(playerEntities[1], "Skills")
    if not skills or not skills.skills[skillName] then
        return config.baseXp  -- Skill not found, return base XP
    end
    
    local skillLevel = skills.skills[skillName].level
    return config.baseXp + (skillLevel * config.scalePerLevel)
end

-- Award XP for a skill and handle level ups
-- @param skillName string: The name of the skill ("mining", "salvaging", "combat", etc.)
-- @param xpAmount number: Optional - if provided, awards exactly this amount. Otherwise uses getXpGain()
function SkillXP.awardXp(skillName, xpAmount)
    if xpAmount == nil then
        xpAmount = SkillXP.getXpGain(skillName)
    end
    
    SkillUtils.addSkillExperience(skillName, xpAmount)
end

return SkillXP
