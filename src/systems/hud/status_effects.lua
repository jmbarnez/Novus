---@diagnostic disable: undefined-global
-- HUD Status Effects - renders status effect icons above the hotbar

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local Theme = require('src.ui.theme')
local HUDHotbar = require('src.systems.hud.hotbar')

local StatusEffectsHUD = {}

local ICON_SIZE = 34
local ICON_SPACING = 10
local BAR_MARGIN = 16

local cachedFont = nil

local function ensureFont()
    if not cachedFont then
        cachedFont = Theme.getFont(Theme.fonts.tiny)
    end
end

local function getPlayerShip()
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then
        return nil
    end

    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if input and input.targetEntity then
        return input.targetEntity
    end

    return nil
end

local function gatherStatusEffects()
    local effects = {}
    local shipId = getPlayerShip()
    if not shipId then
        return effects
    end

    local energy = ECS.getComponent(shipId, "Energy")
    if energy and energy.max and energy.max > 0 then
        local ratio = math.max(0, (energy.current or 0) / energy.max)
        if ratio <= 0.4 then
            local severity = math.min(1, (0.4 - ratio) / 0.4)
            effects[#effects + 1] = {
                id = "low_energy",
                label = "LOW",
                severity = severity
            }
        end
    end

    return effects
end

local function drawLowEnergyIcon(x, y, size, severity)
    local corner = math.max(2, size * 0.18)

    love.graphics.setColor(0.06, 0.06, 0.09, 0.92)
    love.graphics.rectangle("fill", x, y, size, size, corner, corner)

    love.graphics.setColor(1.0, 0.85, 0.15, 0.95)
    love.graphics.setLineWidth(math.max(1, size * 0.08))
    love.graphics.rectangle("line", x + 1, y + 1, size - 2, size - 2, corner, corner)
    love.graphics.setLineWidth(1)

    local cx = x + size / 2
    local bolt = {
        cx - size * 0.12, y + size * 0.12,
        cx + size * 0.10, y + size * 0.12,
        cx,               y + size * 0.40,
        cx + size * 0.18, y + size * 0.40,
        cx - size * 0.26, y + size * 0.88,
        cx - size * 0.08, y + size * 0.56,
        cx - size * 0.26, y + size * 0.56
    }

    love.graphics.setColor(1.0, 0.9, 0.2, 0.96)
    love.graphics.polygon("fill", bolt)

    love.graphics.setColor(1.0, 0.6, 0.15, 0.85)
    love.graphics.setLineWidth(math.max(1, size * 0.04))
    love.graphics.polygon("line", bolt)
    love.graphics.setLineWidth(1)

    if severity and severity > 0 then
        local overlayHeight = size * severity
        love.graphics.setColor(1.0, 0.25, 0.15, 0.35)
        love.graphics.rectangle("fill", x, y + size - overlayHeight, size, overlayHeight, corner, corner)
    end

    ensureFont()
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(cachedFont)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("E!", x, y + size * 0.32, size, "center")
    love.graphics.setFont(previousFont)
end

local function drawEffect(effect, x, y, size)
    if effect.id == "low_energy" then
        drawLowEnergyIcon(x, y, size, effect.severity)
    end
end

function StatusEffectsHUD.drawStatusEffects(viewportWidth, viewportHeight)
    local effects = gatherStatusEffects()
    if #effects == 0 then
        return
    end

    local metrics = HUDHotbar.getHotbarMetrics()
    local scale = math.min(metrics.scaleX, metrics.scaleY)
    local iconSize = ICON_SIZE * scale
    local spacing = ICON_SPACING * scale
    local margin = BAR_MARGIN * scale

    local totalWidth = iconSize * #effects + spacing * math.max(0, #effects - 1)
    local baseX = metrics.x + (metrics.width - totalWidth) / 2
    local baseY = metrics.y - iconSize - margin

    local prevR, prevG, prevB, prevA = love.graphics.getColor()
    local prevLineWidth = love.graphics.getLineWidth()

    for index, effect in ipairs(effects) do
        local drawX = baseX + (index - 1) * (iconSize + spacing)
        drawEffect(effect, drawX, baseY, iconSize)
    end
    
    love.graphics.setColor(prevR, prevG, prevB, prevA)
    love.graphics.setLineWidth(prevLineWidth)
end

return StatusEffectsHUD
