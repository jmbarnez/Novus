---@diagnostic disable: undefined-global
-- UI Skills Panel Module - Handles skills display (panel logic only, no window)

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')

local SkillsPanel = {}

-- Draw the skills panel content
function SkillsPanel.draw(x, y, width, height, alpha)
    local contentX = x + 10
    local contentY = y + 10
    local contentWidth = width - 20
    local contentHeight = height - 20

    -- Get player skills
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then return end

    local playerId = playerEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills then return end

    -- Draw title
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Skills", contentX, contentY, contentWidth, "center")

    -- Draw divider line
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.line(contentX + 8, contentY + 30, contentX + contentWidth - 8, contentY + 30)

    -- Draw mining skill
    local miningSkill = skills.skills.mining
    if miningSkill then
        local skillY = contentY + 40
        SkillsPanel.drawSkillEntry("Mining", miningSkill, contentX, skillY, contentWidth, alpha, {0.2, 0.6, 1.0})
    end

    -- Draw salvaging skill
    local salvagingSkill = skills.skills.salvaging
    if salvagingSkill then
        local skillY = contentY + 40 + 58  -- Offset below mining skill
        SkillsPanel.drawSkillEntry("Salvaging", salvagingSkill, contentX, skillY, contentWidth, alpha, {0.2, 1.0, 0.2})
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

