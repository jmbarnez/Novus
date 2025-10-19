---@diagnostic disable: undefined-global
-- HUD System - Always-on HUD elements (speed, hull/shield)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local HUDSystem = {
    name = "HUDSystem",
    -- HUD should be drawn inside the canvas (screen-space overlay)
    visible = true -- HUD is visible by default, force true on load
}

local function drawSpeedText(viewportWidth, viewportHeight)
    -- Find pilot entity and their controlled drone
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local velocity = ECS.getComponent(input.targetEntity, "Velocity")
    if not velocity then return end
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)

    -- Position under minimap (top-right, in screen space)
    local minimapSize = 150  -- True pixel size for HUD
    local x = viewportWidth - minimapSize - 20
    local y = 150 + 30

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(string.format("%.1f u/s", speed), x, y, minimapSize, "center")
end

local function drawHullShieldBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local hull = ECS.getComponent(input.targetEntity, "Hull")
    local shield = ECS.getComponent(input.targetEntity, "Shield")
    if not hull then return end

    local barWidth = Scaling.scaleSize(Constants.ui_health_bar_width)
    local barHeight = Scaling.scaleSize(Constants.ui_health_bar_height)
    local x = Scaling.scaleX(20)
    local y = Scaling.scaleY(20)
    local skew = Scaling.scaleSize(15)  -- Skew amount for parallelogram effect

    -- Background parallelogram
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.polygon("fill", 
        x, y, 
        x + barWidth + skew, y, 
        x + barWidth, y + barHeight, 
        x - skew, y + barHeight
    )

    -- Shield (if present) - draw above hull in blue
    if shield and shield.max > 0 then
        local sRatio = math.min((shield.current or 0) / shield.max, 1.0)
        local sFill = barWidth * sRatio
        love.graphics.setColor(0.2, 0.6, 1, 0.9)
        love.graphics.polygon("fill", x, y - barHeight - 4, x + sFill + skew, y - barHeight - 4, x + sFill, y - 4, x - skew, y - 4)
    end
    -- Hull fill parallelogram
    local hullRatio = math.min((hull.current or 0) / hull.max, 1.0)
    local fillWidth = barWidth * hullRatio
    love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
    love.graphics.polygon("fill", 
        x, y, 
        x + fillWidth + skew, y, 
        x + fillWidth, y + barHeight, 
        x - skew, y + barHeight
    )
end


local Minimap = require('src.systems.minimap')

-- HUDSystem.visible = true -- HUD is visible by default

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

-- Allow draw to be called with or without arguments (fallback to love.graphics.getWidth/Height)
function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080
    drawHullShieldBar(viewportWidth, viewportHeight)
    -- Draw minimap as part of HUD
    if Minimap and Minimap.draw then
        Minimap.draw()
    end
    drawSpeedText(viewportWidth, viewportHeight)

    -- Draw notifications and experience pop-ups as part of HUD
    local Notifications = require('src.ui.notifications')
    local SkillNotifications = require('src.ui.skill_notifications')
    Notifications.draw(0, 0, 1)
    SkillNotifications.draw()
end

return HUDSystem
