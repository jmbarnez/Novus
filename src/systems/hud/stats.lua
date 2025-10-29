---@diagnostic disable: undefined-global
-- HUD Stats Module - FPS counter, speed text, hull/shield bars
-- Uses batched rendering and text caching for performance

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')
local BatchRenderer = require('src.ui.batch_renderer')
local LevelUtils = require('src.level_utils')

local HUDStats = {}

-- Text caching to avoid string formatting every frame
local vitalsLevelFont = nil
local cachedFpsText = ""
local cachedSpeedText = ""
local lastFps = 0
local lastSpeed = 0
local lastTargetFps = nil
local textCacheFrames = 0
local TEXT_CACHE_INTERVAL = 5  -- Update text every N frames

local function ensureVitalsFonts()
    if not vitalsLevelFont then
        vitalsLevelFont = Theme.getFont(math.floor(Theme.fonts.title * 1.4))
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
    local color = Theme.colors.text

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
    -- Use themed surface colors for the panel background and header accent
    local surf = Theme.colors.surface or {0.1,0.1,0.1,1}
    local surfAlt = Theme.colors.surfaceAlt or {0.12,0.12,0.12,1}
    local border = Theme.colors.border or {0.06,0.06,0.06,1}

    BatchRenderer.queueRect(x, y, width, height, surf[1], surf[2], surf[3], (surf[4] or 1) * 0.95, 0)
    BatchRenderer.queueRect(x, y, width, accentHeight, surfAlt[1], surfAlt[2], surfAlt[3], (surfAlt[4] or 1) * 0.6, 0)
    BatchRenderer.queueRectLine(x, y, width, height, border[1], border[2], border[3], (border[4] or 1) * 0.9, 1, 0)
end

function HUDStats.drawPlayerVitals(viewportWidth, viewportHeight)
    local shipId = getPlayerShip()
    if not shipId then
        return
    end

    local hull = ECS.getComponent(shipId, "Hull")
    if not hull then
        return
    end

    local shield = ECS.getComponent(shipId, "Shield")
    local energy = ECS.getComponent(shipId, "Energy")
    local levelData = LevelUtils.getPlayerLevelData() or { level = 1, experience = 0, requiredXp = 200 }

    ensureVitalsFonts()

    local padding = Scaling.scaleSize(16)
    local panelWidth = Scaling.scaleSize(260)
    -- make the vitals panel slightly shorter vertically
    local panelHeight = Scaling.scaleSize(72)
    local levelBlockWidth = Scaling.scaleSize(58)
    local accentMargin = Scaling.scaleSize(10)

    local x = Scaling.scaleX(padding)
    local y = Scaling.scaleY(padding)

    local contentX = x + levelBlockWidth + accentMargin
    local contentWidth = panelWidth - levelBlockWidth - accentMargin * 2

    queueSleekBackground(x, y, panelWidth, panelHeight, Scaling.scaleSize(4))

    -- Level column with XP band
    local surf = Theme.colors.surface or {0.1,0.1,0.1,1}
    local surfAlt = Theme.colors.surfaceAlt or {0.12,0.12,0.12,1}
    local border = Theme.colors.border or {0.06,0.06,0.06,1}

    BatchRenderer.queueRect(x, y, levelBlockWidth, panelHeight, surf[1], surf[2], surf[3], (surf[4] or 1) * 0.9, 0)
    BatchRenderer.queueRect(x, y, levelBlockWidth, panelHeight * 0.4, surfAlt[1], surfAlt[2], surfAlt[3], (surfAlt[4] or 1) * 0.5, 0)
    BatchRenderer.queueRectLine(x, y, levelBlockWidth, panelHeight, border[1], border[2], border[3], (border[4] or 1) * 0.9, 1, 0)

    local levelText = string.format("%02d", levelData.level or 1)
    -- guard against nil font and compute height safely for vertical centering
    local fontHeight = (vitalsLevelFont and vitalsLevelFont.getHeight) and vitalsLevelFont:getHeight() or 0
    local levelTextY = y + panelHeight * 0.34 - fontHeight / 2
    BatchRenderer.queueText(levelText, x, levelTextY, vitalsLevelFont, 0.9, 0.96, 1.0, 0.94, "center", levelBlockWidth)

    local xpRatio = 0
    if levelData.requiredXp and levelData.requiredXp > 0 then
        xpRatio = math.max(0, math.min(1, (levelData.experience or 0) / levelData.requiredXp))
    end
    local xpPad = Scaling.scaleSize(8)
    local xpWidth = levelBlockWidth - xpPad * 2
    local xpHeight = Scaling.scaleSize(4)
    local xpY = y + panelHeight - xpHeight - xpPad
    local surfLight = Theme.colors.surfaceLight or {0.15,0.15,0.15,1}
    local accent = Theme.colors.accent or {0.6,0.8,1,1}
    BatchRenderer.queueRect(x + xpPad, xpY, xpWidth, xpHeight, surfLight[1], surfLight[2], surfLight[3], (surfLight[4] or 1) * 0.7, 0)
    if xpRatio > 0 then
        local fillWidth = xpWidth * xpRatio
        BatchRenderer.queueRect(x + xpPad, xpY, fillWidth, xpHeight, accent[1], accent[2], accent[3], (accent[4] or 1) * 0.9, 0)
        BatchRenderer.queueRect(x + xpPad, xpY, fillWidth, math.max(1, xpHeight * 0.45), accent[1], accent[2], accent[3], (accent[4] or 1) * 0.5, 0)
    end

    -- Combined hull/shield bar
    local hullRatio, shieldRatio = calculateHullShieldRatios(hull, shield)
    local hybridHeight = Scaling.scaleSize(24)
    -- nudge the hybrid bars a bit up to fit the shorter panel
    local hybridY = y + Scaling.scaleSize(12)

    BatchRenderer.queueRect(contentX, hybridY, contentWidth, hybridHeight, 0.03, 0.035, 0.07, 0.95, 0)
    BatchRenderer.queueRect(contentX, hybridY - Scaling.scaleSize(2), contentWidth, Scaling.scaleSize(2), 0.26, 0.66, 1.0, 0.28, 0)

    local hullWidth = math.max(0, (contentWidth - 4) * hullRatio)
    if hullWidth > 0 then
        BatchRenderer.queueRect(contentX + 2, hybridY + 2, hullWidth, hybridHeight - 4, 0.88, 0.2, 0.46, 0.88, 0)
        BatchRenderer.queueRect(contentX + 2, hybridY + 2, hullWidth, math.max(2, (hybridHeight - 4) * 0.35), 1.0, 0.42, 0.64, 0.55, 0)
    end

    if shieldRatio > 0 then
        local shieldWidth = math.max(0, (contentWidth - 6) * shieldRatio)
        -- Draw shield filling left-to-right like the hull bar
        local shieldX = contentX + 2
        BatchRenderer.queueRect(shieldX, hybridY + 4, shieldWidth, hybridHeight - 8, 0.12, 0.74, 1.0, 0.72, 0)
        BatchRenderer.queueRect(shieldX, hybridY + 4, shieldWidth, math.max(2, (hybridHeight - 8) * 0.42), 0.54, 0.94, 1.0, 0.6, 0)
    end
    BatchRenderer.queueRectLine(contentX, hybridY, contentWidth, hybridHeight, 0.2, 0.28, 0.5, 0.9, 2, 0)

    -- Energy bar
    if energy and energy.max and energy.max > 0 then
        local energyRatio = math.max(0, math.min(1, (energy.current or 0) / energy.max))
        local energyHeight = Scaling.scaleSize(12)
        -- reduce spacing between hybrid and energy bar to save vertical space
        local energyY = hybridY + hybridHeight + Scaling.scaleSize(8)

        BatchRenderer.queueRect(contentX, energyY, contentWidth, energyHeight, 0.04, 0.05, 0.1, 0.95, 0)
        BatchRenderer.queueRect(contentX, energyY - Scaling.scaleSize(2), contentWidth, Scaling.scaleSize(2), 1.0, 0.58, 0.22, 0.35, 0)

        local energyWidth = math.max(0, (contentWidth - 4) * energyRatio)
        if energyWidth > 0 then
            BatchRenderer.queueRect(contentX + 2, energyY + 2, energyWidth, energyHeight - 4, 1.0, 0.84, 0.18, 0.94, 0)
            BatchRenderer.queueRect(contentX + 2, energyY + 2, energyWidth, math.max(2, (energyHeight - 4) * 0.4), 1.0, 0.92, 0.48, 0.65, 0)
            local sparkWidth = math.max(Scaling.scaleSize(6), energyWidth * 0.1)
            BatchRenderer.queueRect(contentX + 2 + energyWidth - sparkWidth, energyY + 2, sparkWidth, energyHeight - 4, 1.0, 0.98, 0.52, 0.4, 0)
        end

        BatchRenderer.queueRectLine(contentX, energyY, contentWidth, energyHeight, 0.22, 0.24, 0.4, 0.9, 1.6, 0)
    end
end

function HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
    HUDStats.drawPlayerVitals(viewportWidth, viewportHeight)
end

function HUDStats.drawEnergyBar(viewportWidth, viewportHeight)
    -- Energy bar rendered within drawPlayerVitals for the new HUD layout
end

return HUDStats

