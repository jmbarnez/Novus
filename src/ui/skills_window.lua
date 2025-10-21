---@diagnostic disable: undefined-global
-- UI Skills Window Module - Handles skills display and experience tracking
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

-- Create skills window instance inheriting from WindowBase
local SkillsWindow = WindowBase:new{
    width = 300,
    height = 200,
    isOpen = false,
    animAlphaSpeed = 2.5,
    elasticitySpring = 18,
    elasticityDamping = 0.7,
}

-- Public interface for toggling
function SkillsWindow:toggle()
    self:setOpen(not self.isOpen)
end

function SkillsWindow:getOpen()
    return self.isOpen
end

-- Override draw to add skills-specific content on top of universal window
---@diagnostic disable-next-line: duplicate-set-field
function SkillsWindow:draw(viewportWidth, viewportHeight)
    -- Draw base window (background, top/bottom bars, dividers)
    WindowBase.draw(self)

    -- Check if should be visible
    if not self.isOpen and not self.animAlphaActive then return end

    local alpha = self.animAlpha
    if alpha <= 0 then return end

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height

    -- Draw close button
    self:drawCloseButton(x, y, alpha)

    -- Draw skills content
    self:drawSkillsContentOnly(x, y, alpha)
end

-- Draw only the skills content without window frame (for tabbed interface)
function SkillsWindow:drawSkillsContentOnly(windowX, windowY, alpha)
    self:drawSkillsContent(windowX, windowY, alpha)
end

function SkillsWindow:drawSkillsContent(windowX, windowY, alpha)
    local contentX = windowX + Theme.window.topBarHeight
    local contentY = windowY + Theme.window.topBarHeight + 10
    local contentWidth = self.width - Theme.window.topBarHeight * 2
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 20

    -- Get player skills
    local cargoEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #cargoEntities == 0 then return end

    local playerId = cargoEntities[1]
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
        -- Skill name
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.print("Mining", contentX + 8, skillY)
        -- Skill level
        love.graphics.printf("Lvl " .. miningSkill.level, contentX + 8, skillY + 12, contentWidth - 16, "right")
        -- Experience bar background
        local barX = contentX + 8
        local barY = skillY + 28
        local barWidth = contentWidth - 16
        local barHeight = 12
        love.graphics.setColor(0.1, 0.1, 0.1, alpha)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        -- Experience bar border
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
        -- Experience bar fill (gradient blue-cyan)
        local xpRatio = math.min(1, miningSkill.experience / miningSkill.requiredXp)
        local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
        love.graphics.setColor(0.2, 0.6, 1.0, alpha)
        love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2)
    end

    -- Draw salvaging skill
    local salvagingSkill = skills.skills.salvaging
    if salvagingSkill then
        local skillY = contentY + 40 + 58  -- Offset below mining skill
        -- Skill name
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.print("Salvaging", contentX + 8, skillY)
        -- Skill level
        love.graphics.printf("Lvl " .. salvagingSkill.level, contentX + 8, skillY + 12, contentWidth - 16, "right")
        -- Experience bar background
        local barX = contentX + 8
        local barY = skillY + 28
        local barWidth = contentWidth - 16
        local barHeight = 12
        love.graphics.setColor(0.1, 0.1, 0.1, alpha)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        -- Experience bar border
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
        -- Experience bar fill (gradient green)
        local xpRatio = math.min(1, salvagingSkill.experience / salvagingSkill.requiredXp)
        local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
        love.graphics.setColor(0.2, 1.0, 0.2, alpha)  -- Green for salvaging
        love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2)
    end
end

-- Close button is handled by WindowBase

return SkillsWindow
