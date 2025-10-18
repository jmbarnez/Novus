---@diagnostic disable: undefined-global
-- HUD System - Always-on HUD elements (speed, health)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')

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

    -- Position under minimap (assuming minimap is in top-right corner)
    local minimapSize = 150  -- Approximate minimap size
    local x = viewportWidth - minimapSize - 20
    local y = minimapSize + 30  -- Position under minimap

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(string.format("%.1f u/s", speed), x, y, minimapSize, "center")
end

local function drawHealthBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local health = ECS.getComponent(input.targetEntity, "Health")
    if not health then return end

    local barWidth = Constants.ui_health_bar_width
    local barHeight = Constants.ui_health_bar_height
    local x = 20
    local y = 20
    local skew = 15  -- Skew amount for parallelogram effect

    -- Background parallelogram
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.polygon("fill", 
        x, y, 
        x + barWidth + skew, y, 
        x + barWidth, y + barHeight, 
        x - skew, y + barHeight
    )

    -- Health fill parallelogram
    local healthRatio = math.min(health.current / health.max, 1.0)
    local fillWidth = barWidth * healthRatio
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
    drawHealthBar(viewportWidth, viewportHeight)
    -- Draw minimap as part of HUD
    if Minimap and Minimap.draw then
        Minimap.draw()
    end
    drawSpeedText(viewportWidth, viewportHeight)
end

return HUDSystem
