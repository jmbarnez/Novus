-- UI System - Manages all heads-up display elements
-- Renders UI components like speed indicators and health bars

local ECS = require('src.ecs')
local Constants = require('src.constants')

-- Helper function to draw a sleek speed indicator
local function drawSpeedIndicator(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Velocity"})
    if #playerEntities == 0 then return end

    local playerId = playerEntities[1]
    local velocity = ECS.getComponent(playerId, "Velocity")
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)

    -- Bar settings
    local barWidth = Constants.ui_speed_bar_width
    local barHeight = Constants.ui_speed_bar_height
    local x = viewportWidth - barWidth - 20
    local y = viewportHeight - barHeight - 20

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)

    -- Draw speed fill
    local maxSpeed = Constants.player_max_speed -- From Physics component
    local speedRatio = math.min(speed / maxSpeed, 1.0)
    local fillColor = {0.2, 0.6, 1.0, 0.9} -- Blueish
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, barWidth * speedRatio, barHeight)

    -- Draw text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Speed: %d", speed), x, y + 5, barWidth, "center")
end

-- Helper function to draw a sleek health bar
local function drawHealthBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Health"})
    if #playerEntities == 0 then return end

    local playerId = playerEntities[1]
    local health = ECS.getComponent(playerId, "Health")

    -- Bar settings
    local barWidth = Constants.ui_health_bar_width
    local barHeight = Constants.ui_health_bar_height
    local x = 20
    local y = 20

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)

    -- Draw health fill
    local healthRatio = math.min(health.current / health.max, 1.0)
    local fillColor = {1.0, 0.2, 0.2, 0.9} -- Redish
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, barWidth * healthRatio, barHeight)

    -- Draw text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Hull: %d%%", health.current / health.max * 100), x, y + 5, barWidth, "center")
end

local UISystem = {
    name = "UISystem",

    draw = function(viewportWidth, viewportHeight)
        local uiEntities = ECS.getEntitiesWith({"UI"})

        for _, entityId in ipairs(uiEntities) do
            local ui = ECS.getComponent(entityId, "UI")

            if ui.uiType == "hud" then
                -- Draw all HUD elements
                drawSpeedIndicator(viewportWidth, viewportHeight)
                drawHealthBar(viewportWidth, viewportHeight)
            end
        end
    end
}

return UISystem