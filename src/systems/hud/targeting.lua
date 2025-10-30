-- HUD Targeting Module - Targeting panel display

local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')

local HUDTargeting = {}

function HUDTargeting.drawTargetingPanel(viewportWidth, viewportHeight)
    -- This panel has been removed - target info now shows on hover via TargetHUD
    return
end

return HUDTargeting

