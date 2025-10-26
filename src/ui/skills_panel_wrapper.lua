local SkillsPanel = require('src.ui.skills_panel')
local SkillsPanelWrapper = {}

function SkillsPanelWrapper.draw(self, windowX, windowY, width, height, alpha)
    SkillsPanel.draw(windowX, windowY, width, height, alpha)
end

function SkillsPanelWrapper.mousepressed(self, x, y, button) end
function SkillsPanelWrapper.mousereleased(self, x, y, button) end
function SkillsPanelWrapper.mousemoved(self, x, y, dx, dy) end

return SkillsPanelWrapper
