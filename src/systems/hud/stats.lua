---@diagnostic disable: undefined-global
-- HUD Stats Module - FPS counter, speed text, hull/shield bars
-- Uses batched rendering and text caching for performance

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Constants = require('src.constants')
local TimeManager = require('src.time_manager')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDStats = {}

-- Text caching to avoid string formatting every frame
local cachedFpsText = ""
local cachedSpeedText = ""
local lastFps = 0
local lastSpeed = 0
local lastTargetFps = nil
local textCacheFrames = 0
local TEXT_CACHE_INTERVAL = 5  -- Update text every N frames

function HUDStats.drawFpsCounter(viewportWidth, viewportHeight)
    local fps = TimeManager.getFps()
    local targetFps = TimeManager.getTargetFps()
    
    -- Only update text if FPS changed significantly or cache expired
    textCacheFrames = textCacheFrames + 1
    if textCacheFrames >= TEXT_CACHE_INTERVAL or math.abs(fps - lastFps) > 2 or targetFps ~= lastTargetFps then
        if targetFps then
            cachedFpsText = string.format("FPS: %d / %d", fps, targetFps)
        else
            cachedFpsText = string.format("FPS: %d (Unlocked)", fps)
        end
        lastFps = fps
        lastTargetFps = targetFps
        textCacheFrames = 0
    end
    
    local color
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
    
    local font = Theme.getFont(Theme.fonts.tiny)
    local textWidth = font:getWidth(cachedFpsText)
    local x = Scaling.REFERENCE_WIDTH - textWidth - 10
    local y = 10
    
    BatchRenderer.queueText(cachedFpsText, x, y, font, color[1], color[2], color[3], color[4])
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

    -- Cache speed text if it hasn't changed much
    if math.abs(speed - lastSpeed) > 0.5 or cachedSpeedText == "" then
        cachedSpeedText = string.format("%.1f u/s", speed)
        lastSpeed = speed
    end

    local minimapSize = 150
    local x = Scaling.REFERENCE_WIDTH - minimapSize - 20
    local y = 150 + 30
    local font = Theme.getFont(Theme.fonts.normal)
    local color = Theme.colors.textPrimary

    BatchRenderer.queueText(cachedSpeedText, x, y, font, color[1], color[2], color[3], color[4], "center", minimapSize)
end

function HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    -- Get hull and shield from the player's drone
    local hull = ECS.getComponent(input.targetEntity, "Hull")
    local shield = ECS.getComponent(input.targetEntity, "Shield")
    if not hull then return end
    
    local barWidth = Scaling.scaleSize(Constants.ui_health_bar_width)
    local barHeight = Scaling.scaleSize(Constants.ui_health_bar_height)
    local padding = Scaling.scaleSize(12)
    local x = Scaling.scaleX(padding)
    local y = Scaling.scaleY(padding)

    -- Combined hull/shield bar - shield overlays hull
    local hullRatio = math.min((hull.current or 0) / hull.max, 1.0)
    local shieldRatio = 0
    if shield and shield.max > 0 then
        shieldRatio = math.min((shield.current or 0) / shield.max, 1.0)
    end
    
    -- Background
    local bgColor = PlasmaTheme.colors.healthBarBg
    BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 2)
    
    -- Hull fill (always draw full hull bar as background)
    local hullColor = PlasmaTheme.colors.healthBarFill
    local hullWidth = math.max(0, (barWidth - 2) * hullRatio)
    if hullWidth > 0 then
        BatchRenderer.queueRect(x + 1, y + 1, hullWidth, barHeight - 2, hullColor[1], hullColor[2], hullColor[3], hullColor[4], 1)
    end
    
    -- Shield overlay (draws on top of hull, showing hull underneath as it depletes)
    if shield and shield.max > 0 then
        local shieldColor = PlasmaTheme.colors.shieldBarFill
        local shieldWidth = math.max(0, (barWidth - 2) * shieldRatio)
        if shieldWidth > 0 then
            BatchRenderer.queueRect(x + 1, y + 1, shieldWidth, barHeight - 2, shieldColor[1], shieldColor[2], shieldColor[3], shieldColor[4], 0)
        end
    end
    
    -- Outline
    local outlineColor = PlasmaTheme.colors.outlineBlack
    BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], PlasmaTheme.colors.outlineThick, 2)
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
    
    -- Position below the combined hull/shield bar (only one bar now)
    local y = Scaling.scaleY(padding + barHeight + 4)
    
    local energyRatio = math.min((energy.current or 0) / energy.max, 1.0)
    
    -- Draw energy bar using batched rendering
    -- Background
    local bgColor = PlasmaTheme.colors.healthBarBg
    BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 2)
    
    -- Energy bar fill (bright yellow - plasma energy color)
    local fillColor = PlasmaTheme.colors.asteroidBarFill
    local fillWidth = math.max(0, (barWidth - 2) * energyRatio)
    if fillWidth > 0 then
        BatchRenderer.queueRect(x + 1, y + 1, fillWidth, barHeight - 2, fillColor[1], fillColor[2], fillColor[3], fillColor[4], 1)
    end
    
    -- Thick black outline (consistent with hull/shield bars)
    local outlineColor = PlasmaTheme.colors.outlineBlack
    BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], PlasmaTheme.colors.outlineThick, 2)
end

return HUDStats

