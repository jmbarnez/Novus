---@diagnostic disable: undefined-global
-- UI Skills Panel Module - Handles skills display (panel logic only, no window)

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')

local SkillsPanel = {}

-- Draw the skills panel content
function SkillsPanel.draw(x, y, width, height, alpha)
    local contentX = x + 10
    local contentY = y + Theme.window.topBarHeight + 60 + 40 + 10  -- Account for topBarHeight (32) + tabHeight (60) + spacing (40) + padding (10)
    local contentWidth = width - 20
    local contentHeight = height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 60 - 40 - 20  -- Account for all UI elements

    -- Get player skills
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then return end

    local playerId = playerEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills then return end

    local currentY = contentY

    -- Draw mining skill
    local miningSkill = skills.skills.mining
    if miningSkill then
        SkillsPanel.drawSkillEntry("Mining", miningSkill, contentX, currentY, contentWidth, alpha, {0.2, 0.6, 1.0})
        currentY = currentY + 58
    end

    -- Draw salvaging skill
    local salvagingSkill = skills.skills.salvaging
    if salvagingSkill then
        SkillsPanel.drawSkillEntry("Salvaging", salvagingSkill, contentX, currentY, contentWidth, alpha, {0.2, 1.0, 0.2})
        currentY = currentY + 58
    end
end

-- Helper to draw a single skill entry
function SkillsPanel.drawSkillEntry(skillName, skill, x, y, width, alpha, barColor)
    -- Skill name
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.print(skillName, x + 8, y)
    
    -- Skill level
    love.graphics.printf("Lvl " .. skill.level, x + 8, y + 12, width - 16, "right")
    
    -- Experience bar background
    local barX = x + 8
    local barY = y + 28
    local barWidth = width - 16
    local barHeight = 12
    love.graphics.setColor(0.1, 0.1, 0.1, alpha)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Experience bar border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    
    -- Experience bar fill
    local xpRatio = math.min(1, skill.experience / skill.requiredXp)
    local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
    love.graphics.setColor(barColor[1], barColor[2], barColor[3], alpha)
    love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2)
end

return SkillsPanel

