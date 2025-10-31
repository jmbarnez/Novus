local SkillsWindow = require('src.ui.skills_window')
local SkillsPanelWrapper = {}

function SkillsPanelWrapper.draw(self, windowX, windowY, width, height, alpha)
    if SkillsWindow and SkillsWindow.drawEmbedded then
        return SkillsWindow.drawEmbedded(self, windowX, windowY, width, height, alpha)
    end
end

function SkillsPanelWrapper.mousepressed(self, x, y, button)
    if SkillsWindow and SkillsWindow.mousepressedEmbedded then
        return SkillsWindow.mousepressedEmbedded(self, x, y, button)
    end
end
function SkillsPanelWrapper.mousereleased(self, x, y, button) end
function SkillsPanelWrapper.mousemoved(self, x, y, dx, dy) end

return SkillsPanelWrapper
