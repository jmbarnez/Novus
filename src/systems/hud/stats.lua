---@diagnostic disable: undefined-global
-- HUD Stats Module - FPS counter, speed text, hull/shield bars
-- Uses batched rendering and text caching for performance

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDStats = {}

-- Text caching to avoid string formatting every frame
local vitalsFontLarge = nil
local vitalsFontSmall = nil
local vitalsFontTiny = nil
local cachedFpsText = ""
local cachedSpeedText = ""
local lastFps = 0
local lastSpeed = 0
local lastTargetFps = nil
local textCacheFrames = 0
local TEXT_CACHE_INTERVAL = 5  -- Update text every N frames

local function ensureVitalsFonts()
    if not vitalsFontLarge then
        vitalsFontLarge = Theme.getFont(Theme.fonts.title)
    end
    if not vitalsFontSmall then
        vitalsFontSmall = Theme.getFont(Theme.fonts.normal)
    end
    if not vitalsFontTiny then
        vitalsFontTiny = Theme.getFont(Theme.fonts.tiny)
    end
end

local function getPlayerShip()
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then
        return nil, nil
    end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then
        return nil, pilotId
    end
    return input.targetEntity, pilotId
end

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
    local x = Scaling.getCurrentWidth() - textWidth - 10
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
    local x = Scaling.getCurrentWidth() - minimapSize - 20
    local y = 150 + 30
    local font = Theme.getFont(Theme.fonts.normal)
    local color = Theme.colors.textPrimary

    BatchRenderer.queueText(cachedSpeedText, x, y, font, color[1], color[2], color[3], color[4], "center", minimapSize)
end

local function calculateHullShieldRatios(hull, shield)
    if not hull or not hull.max or hull.max <= 0 then
        return 0, 0
    end

    local hullCurrent = math.max(0, hull.current or 0)
    local hullRatio = math.max(0, math.min(1, hullCurrent / hull.max))

    local shieldRatio = 0
    if shield and shield.max and shield.max > 0 then
        local shieldCurrent = math.max(0, shield.current or 0)
        shieldRatio = math.max(0, math.min(1, shieldCurrent / shield.max))
    end

    return hullRatio, shieldRatio
end

local function queueSleekBackground(x, y, width, height, accentHeight)
    BatchRenderer.queueRect(x, y, width, height, 0.03, 0.04, 0.08, 0.94, 0)
    BatchRenderer.queueRect(x, y, width, accentHeight, 0.18, 0.35, 0.65, 0.35, 0)
    BatchRenderer.queueRectLine(x, y, width, height, 0.12, 0.16, 0.28, 0.95, 2, 4)
end

function HUDStats.drawPlayerVitals(viewportWidth, viewportHeight)
    local shipId, pilotId = getPlayerShip()
    if not shipId then
        return
    end

    local hull = ECS.getComponent(shipId, "Hull")
    if not hull then
        return
    end

    local shield = ECS.getComponent(shipId, "Shield")
    local energy = ECS.getComponent(shipId, "Energy")
    local levelComp = ECS.getComponent(shipId, "Level") or (pilotId and ECS.getComponent(pilotId, "Level"))
    local level = (levelComp and levelComp.level) or 1

    ensureVitalsFonts()

    local padding = Scaling.scaleSize(14)
    local panelWidth = Scaling.scaleSize(280)
    local panelHeight = Scaling.scaleSize(112)
    local levelBlockWidth = Scaling.scaleSize(58)
    local accentMargin = Scaling.scaleSize(12)

    local x = Scaling.scaleX(padding)
    local y = Scaling.scaleY(padding)

    local contentX = x + levelBlockWidth + accentMargin
    local contentWidth = panelWidth - levelBlockWidth - accentMargin * 2

    queueSleekBackground(x, y, panelWidth, panelHeight, Scaling.scaleSize(6))

    -- Level badge block
    BatchRenderer.queueRect(x, y, levelBlockWidth, panelHeight, 0.08, 0.12, 0.22, 0.95, 0)
    BatchRenderer.queueRect(x + levelBlockWidth - Scaling.scaleSize(6), y, Scaling.scaleSize(6), panelHeight, 0.28, 0.7, 1.0, 0.9, 0)
    BatchRenderer.queueRectLine(x, y, levelBlockWidth, panelHeight, 0.16, 0.22, 0.36, 0.9, 1.8, 0)

    local levelLabelColor = Theme.colors.textSecondary or {0.7, 0.7, 0.8, 0.9}
    local levelValueColor = Theme.colors.textPrimary or {1, 1, 1, 1}
    BatchRenderer.queueText("LV", x, y + Scaling.scaleSize(10), vitalsFontTiny, levelLabelColor[1], levelLabelColor[2], levelLabelColor[3], levelLabelColor[4] or 1, "center", levelBlockWidth)
    BatchRenderer.queueText(tostring(level), x, y + panelHeight * 0.32, vitalsFontLarge, levelValueColor[1], levelValueColor[2], levelValueColor[3], levelValueColor[4] or 1, "center", levelBlockWidth)

    -- Combined hull/shield bar
    local hullRatio, shieldRatio = calculateHullShieldRatios(hull, shield)
    local hullPct = math.floor(hullRatio * 100 + 0.5)
    local shieldPct = math.floor(shieldRatio * 100 + 0.5)

    local hybridHeight = Scaling.scaleSize(30)
    local hybridY = y + Scaling.scaleSize(16)
    BatchRenderer.queueText("HULL / SHIELD", contentX, hybridY - Scaling.scaleSize(12), vitalsFontTiny, levelLabelColor[1], levelLabelColor[2], levelLabelColor[3], 0.85, "left", contentWidth)

    BatchRenderer.queueRect(contentX, hybridY, contentWidth, hybridHeight, 0.06, 0.08, 0.14, 0.92, 0)
    BatchRenderer.queueRect(contentX, hybridY, contentWidth, Scaling.scaleSize(2), 0.29, 0.6, 1.0, 0.4, 0)

    local hullFillWidth = math.max(0, (contentWidth - 2) * hullRatio)
    if hullFillWidth > 0 then
        BatchRenderer.queueRect(contentX + 1, hybridY + 1, hullFillWidth, hybridHeight - 2, 0.95, 0.32, 0.48, 0.92, 0)
    end

    if shieldRatio > 0 then
        local shieldWidth = math.max(0, (contentWidth - Scaling.scaleSize(6)) * shieldRatio)
        local shieldX = contentX + contentWidth - shieldWidth - Scaling.scaleSize(3)
        BatchRenderer.queueRect(shieldX, hybridY + Scaling.scaleSize(4), shieldWidth, hybridHeight - Scaling.scaleSize(8), 0.18, 0.75, 1.0, 0.7, 0)
        BatchRenderer.queueRect(shieldX, hybridY + Scaling.scaleSize(4), shieldWidth, Scaling.scaleSize(3), 0.6, 0.9, 1.0, 0.6, 0)
    end

    BatchRenderer.queueRectLine(contentX, hybridY, contentWidth, hybridHeight, 0.14, 0.2, 0.32, 0.95, 2, 4)

    local statTextColor = Theme.colors.textPrimary or {1, 1, 1, 1}
    local shieldTextColor = Theme.colors.textAccent or {0.5, 0.8, 1.0, 1}
    local textYOffset = hybridY + (hybridHeight - vitalsFontSmall:getHeight()) / 2
    BatchRenderer.queueText(string.format("%d%%", hullPct), contentX + Scaling.scaleSize(6), textYOffset, vitalsFontSmall, statTextColor[1], statTextColor[2], statTextColor[3], statTextColor[4] or 1, "left", contentWidth * 0.5)
    BatchRenderer.queueText(string.format("%d%%", shieldPct), contentX, textYOffset, vitalsFontSmall, shieldTextColor[1], shieldTextColor[2], shieldTextColor[3], shieldTextColor[4] or 1, "right", contentWidth - Scaling.scaleSize(6))

    -- Energy bar
    if energy and energy.max and energy.max > 0 then
        local energyRatio = math.max(0, math.min(1, (energy.current or 0) / energy.max))
        local energyPct = math.floor(energyRatio * 100 + 0.5)
        local energyY = hybridY + hybridHeight + Scaling.scaleSize(18)
        local energyHeight = Scaling.scaleSize(16)

        BatchRenderer.queueText("ENERGY", contentX, energyY - Scaling.scaleSize(10), vitalsFontTiny, levelLabelColor[1], levelLabelColor[2], levelLabelColor[3], 0.85, "left", contentWidth)
        BatchRenderer.queueRect(contentX, energyY, contentWidth, energyHeight, 0.05, 0.07, 0.12, 0.9, 0)
        BatchRenderer.queueRect(contentX, energyY, contentWidth, Scaling.scaleSize(2), 0.25, 0.85, 0.9, 0.5, 0)

        local fillWidth = math.max(0, (contentWidth - 2) * energyRatio)
        if fillWidth > 0 then
            BatchRenderer.queueRect(contentX + 1, energyY + 1, fillWidth, energyHeight - 2, 0.26, 0.85, 0.92, 0.92, 0)
        end

        BatchRenderer.queueRectLine(contentX, energyY, contentWidth, energyHeight, 0.14, 0.2, 0.28, 0.95, 1.6, 4)
        BatchRenderer.queueText(string.format("%d%%", energyPct), contentX, energyY + energyHeight - Scaling.scaleSize(2), vitalsFontTiny, shieldTextColor[1], shieldTextColor[2], shieldTextColor[3], 0.9, "right", contentWidth)
    end
end

function HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
    HUDStats.drawPlayerVitals(viewportWidth, viewportHeight)
end

function HUDStats.drawEnergyBar(viewportWidth, viewportHeight)
    -- Energy bar rendered within drawPlayerVitals for the new HUD layout
end

return HUDStats

