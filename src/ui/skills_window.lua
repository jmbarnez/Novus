---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.plasma_theme')
local ECS = require('src.ecs')
local Scaling = require('src.scaling')

local SkillsWindow = WindowBase:new{
    width = 750,
    height = 600,
    isOpen = false
}

function SkillsWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return shipWin:drawSkillsContent(windowX, windowY, width, height, alpha)
end

function SkillsWindow.mousepressedEmbedded(shipWin, x, y, button)
    return shipWin:handleSkillsMousepressed(x, y, button)
end
function SkillsWindow.mousereleasedEmbedded(shipWin, x, y, button) 
    return shipWin:handleSkillsMousereleased(x, y, button)
end
function SkillsWindow.mousemovedEmbedded(shipWin, x, y, dx, dy) 
    return shipWin:handleSkillsMousemoved(x, y, dx, dy)
end

-- Helper methods (full implementations)
function SkillsWindow:drawSkillsContent(windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 8
    local contentWidth = width - 20
    
    -- Get player skills using EntityHelpers
    local EntityHelpers = require('src.entity_helpers')
    local pilotId = EntityHelpers.getPlayerPilot()
    if not pilotId then return end
    local skills = ECS.getComponent(pilotId, "Skills")
    if not skills or not skills.skills then return end
    
    -- Draw header
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("Skills", contentX, contentY, contentWidth, "center")
    
    local skillY = contentY + 40
    local skillHeight = 60
    local skillPadding = 10
    local progressBarHeight = 8
    local progressBarPadding = 4
    
    -- Skill display order
    local skillOrder = {"mining", "salvaging", "lasers", "missiles", "kinetic"}
    local skillNames = {
        mining = "Mining",
        salvaging = "Salvaging",
        lasers = "Lasers",
        missiles = "Missiles",
        kinetic = "Kinetic"
    }
    
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    
    for i, skillKey in ipairs(skillOrder) do
        local skill = skills.skills[skillKey]
        if skill then
            local y = skillY + (i - 1) * (skillHeight + skillPadding)
            
            -- Draw skill background
            local bg = Theme.colors.surface
            local cornerRadius = Theme.window.cornerRadius or 0
            love.graphics.setColor(bg[1], bg[2], bg[3], 0.8 * alpha)
            love.graphics.rectangle("fill", contentX, y, contentWidth, skillHeight, cornerRadius, cornerRadius)
            
            -- Draw skill name and level
            local skillName = skillNames[skillKey] or skillKey
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
            love.graphics.print(skillName, contentX + 10, y + 8)
            
            local levelText = "Level " .. (skill.level or 1)
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
            love.graphics.print(levelText, contentX + 10, y + 24)
            
            -- Draw XP progress bar
            local progressBarX = contentX + 10
            local progressBarY = y + skillHeight - progressBarHeight - progressBarPadding
            local progressBarWidth = contentWidth - 20
            
            -- Background using plasma theme
            local cornerRadius = Theme.window.cornerRadius or 0
            love.graphics.setColor(Theme.colors.surfaceAlt[1], Theme.colors.surfaceAlt[2], Theme.colors.surfaceAlt[3], alpha)
            love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth, progressBarHeight, cornerRadius, cornerRadius)
            
            -- Progress
            local currentXp = skill.experience or 0
            local requiredXp = skill.requiredXp or 100
            local progress = math.min(1, currentXp / requiredXp)
            local filledWidth = progressBarWidth * progress
            
            if filledWidth > 0 then
                local progressColor = Theme.colors.hover or Theme.palette.accent
                love.graphics.setColor(progressColor[1], progressColor[2], progressColor[3], alpha)
                love.graphics.rectangle("fill", progressBarX, progressBarY, filledWidth, progressBarHeight, cornerRadius, cornerRadius)
            end
            
            -- XP text
            local xpText = string.format("%d / %d XP", currentXp, requiredXp)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
            local textX = progressBarX + progressBarWidth - love.graphics.getFont():getWidth(xpText) - 4
            love.graphics.print(xpText, textX, progressBarY - 12)
        end
    end
end

function SkillsWindow:handleSkillsMousepressed(x, y, button)
    -- Skills window doesn't need interaction for now
    return false
end

function SkillsWindow:handleSkillsMousereleased(x, y, button)
    return false
end

function SkillsWindow:handleSkillsMousemoved(x, y, dx, dy)
    -- Skills window doesn't need hover interaction for now
    return false
end

-- Standalone window behaviour
function SkillsWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    self:drawSkillsContent(x, y, self.width, self.height, alpha)
end

function SkillsWindow:mousepressed(x, y, button)
    -- Let base handle close button and dragging first
    WindowBase.mousepressed(self, x, y, button)
    -- If close button was pressed, WindowBase:setOpen(false) will have been called
    if not self:getOpen() then return true end
    -- If user started dragging the window, consume the event
    if self.isDragging then return true end

    return self:handleSkillsMousepressed(x, y, button)
end

function SkillsWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
    return self:handleSkillsMousereleased(x, y, button)
end

function SkillsWindow:mousemoved(x, y, dx, dy)
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    return self:handleSkillsMousemoved(x, y, dx, dy)
end

return SkillsWindow


