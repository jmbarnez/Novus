---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local SkillsPanel = require('src.ui.skills_panel')

local SkillsWindow = WindowBase:new{
    width = 750,
    height = 600,
    isOpen = false
}

function SkillsWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return SkillsPanel.draw(shipWin, windowX, windowY, width, height, alpha)
end

function SkillsWindow.mousepressedEmbedded(shipWin, x, y, button)
    if SkillsPanel and SkillsPanel.mousepressed then
        return SkillsPanel.mousepressed(shipWin, x, y, button)
    end
end
function SkillsWindow.mousereleasedEmbedded(shipWin, x, y, button) end
function SkillsWindow.mousemovedEmbedded(shipWin, x, y, dx, dy) end

-- Standalone window behaviour
function SkillsWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    SkillsPanel.draw(self, x, y, self.width, self.height, alpha)
end

function SkillsWindow:mousepressed(x, y, button)
    -- Let base handle close button and dragging first
    WindowBase.mousepressed(self, x, y, button)
    -- If close button was pressed, WindowBase:setOpen(false) will have been called
    if not self:getOpen() then return true end
    -- If user started dragging the window, consume the event
    if self.isDragging then return true end

    if SkillsPanel and SkillsPanel.mousepressed then
        return SkillsPanel.mousepressed(self, x, y, button)
    end
end

function SkillsWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
end

function SkillsWindow:mousemoved(x, y, dx, dy)
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    if SkillsPanel and SkillsPanel.mousemoved then
        return SkillsPanel.mousemoved(self, x, y, dx, dy)
    end
end

return SkillsWindow


