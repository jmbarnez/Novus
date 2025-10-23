-- HUD Stats Module - FPS counter, speed text, hull/shield bars

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Constants = require('src.constants')
local TimeManager = require('src.time_manager')
local PlasmaTheme = require('src.ui.plasma_theme')

local HUDStats = {}

function HUDStats.drawFpsCounter(viewportWidth, viewportHeight)
    local fps = TimeManager.getFps()
    local targetFps = TimeManager.getTargetFps()
    
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    
    local fpsText = string.format("FPS: %d", fps)
    if targetFps then
        fpsText = fpsText .. string.format(" / %d", targetFps)
    else
        fpsText = fpsText .. " (Unlocked)"
    end
    
    local color = Theme.colors.textPrimary
    if targetFps then
        if fps >= targetFps * 0.95 then
            color = {0.2, 1, 0.2, 0.8}
        elseif fps >= targetFps * 0.7 then
            color = {1, 1, 0.2, 0.8}
        else
            color = {1, 0.2, 0.2, 0.8}
        end
    else
        color = {0.2, 0.8, 1, 0.8}
    end
    
    love.graphics.setColor(color)
    
    local textWidth = Theme.getFont(Theme.fonts.tiny):getWidth(fpsText)
    local x = viewportWidth - textWidth - 10
    local y = 10
    
    love.graphics.print(fpsText, x, y)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function HUDStats.drawSpeedText(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local velocity = ECS.getComponent(input.targetEntity, "Velocity")
    if not velocity then return end
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)

    local minimapSize = 150
    local x = viewportWidth - minimapSize - 20
    local y = 150 + 30

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(string.format("%.1f u/s", speed), x, y, minimapSize, "center")
end

function HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
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
    local padding = Scaling.scaleSize(12)
    local x = Scaling.scaleX(padding)
    local y = Scaling.scaleY(padding)

    -- Draw hull bar first (at top)
    local hullRatio = math.min((hull.current or 0) / hull.max, 1.0)
    PlasmaTheme.drawHealthBar(x, y, barWidth, barHeight, hullRatio, false)
    
    -- Draw shield bar below hull bar (if exists)
    if shield and shield.max > 0 then
        local sRatio = math.min((shield.current or 0) / shield.max, 1.0)
        local shieldY = y + barHeight + 4  -- Offset below hull bar
        PlasmaTheme.drawHealthBar(x, shieldY, barWidth, barHeight, sRatio, true)
    end
end

function HUDStats.drawEnergyBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local energy = ECS.getComponent(input.targetEntity, "Energy")
    if not energy then return end
    
    local barWidth = Scaling.scaleSize(Constants.ui_health_bar_width)
    local barHeight = Scaling.scaleSize(Constants.ui_health_bar_height)
    local padding = Scaling.scaleSize(12)
    local x = Scaling.scaleX(padding)
    
    -- Position below hull/shield bars (accounting for both bars if shield exists)
    local shield = ECS.getComponent(input.targetEntity, "Shield")
    local offset = shield and shield.max > 0 and (barHeight * 2 + 8) or (barHeight + 4)
    local y = Scaling.scaleY(padding + offset)
    
    local energyRatio = math.min((energy.current or 0) / energy.max, 1.0)
    
    -- Draw energy bar background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 2, 2)
    
    -- Draw energy bar fill (bright yellow)
    love.graphics.setColor(1.0, 0.9, 0.2, 0.9)
    love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (barWidth - 2) * energyRatio), barHeight - 2, 1, 1)
    
    -- Draw outline
    love.graphics.setColor(0.3, 0.3, 0.4, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, barWidth, barHeight, 2, 2)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return HUDStats

