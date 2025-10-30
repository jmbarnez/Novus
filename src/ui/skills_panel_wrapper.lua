local SkillsPanel = require('src.ui.skills_panel')
local SkillsPanelWrapper = {}

function SkillsPanelWrapper.draw(self, windowX, windowY, width, height, alpha)
    SkillsPanel.draw(self, windowX, windowY, width, height, alpha)
end

function SkillsPanelWrapper.mousepressed(self, x, y, button)
    if SkillsPanel and SkillsPanel.mousepressed then
        -- x, y are already in UI space from ShipWindow
        SkillsPanel.mousepressed(self, x, y, button)
    end
end
function SkillsPanelWrapper.mousereleased(self, x, y, button) end
function SkillsPanelWrapper.mousemoved(self, x, y, dx, dy) end

return SkillsPanelWrapper
