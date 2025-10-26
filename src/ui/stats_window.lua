---@diagnostic disable: undefined-global
-- Ship Stats Window - Dedicated view for detailed ship statistics

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local Constants = require('src.constants')
local TurretRegistry = require('src.turret_registry')
local Scaling = require('src.scaling')

local StatsWindow = WindowBase:new{
    width = 420,
    height = 540,
    isOpen = false
}

function StatsWindow:getOpen()
    return self.isOpen
end

function StatsWindow:toggle()
    self:setOpen(not self.isOpen)
end

function StatsWindow:mousepressed(mx, my, button)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    WindowBase.mousepressed(self, sx, sy, button)
end

function StatsWindow:mousereleased(mx, my, button)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    WindowBase.mousereleased(self, sx, sy, button)
end

function StatsWindow:mousemoved(mx, my, dx, dy)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    local sdx, sdy = Scaling.toScreenCanvas(mx + dx, my + dy)
    WindowBase.mousemoved(self, sx, sy, sdx - sx, sdy - sy)
end

local function gatherShipData()
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then
        return nil, {
            { title = "Status", lines = {"No active pilot detected."} }
        }
    end

    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then
        return nil, {
            { title = "Status", lines = {"No ship linked to pilot."} }
        }
    end

    local droneId = input.targetEntity

    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")
    local energy = ECS.getComponent(droneId, "Energy")
    local physics = ECS.getComponent(droneId, "Physics")
    local turret = ECS.getComponent(droneId, "Turret")

    local mass = physics and physics.mass or 1
    local baseMaxVelocity = Constants.player_max_speed or 0
    local maxVelocity = baseMaxVelocity / math.max(mass, 0.01)
    local acceleration = maxVelocity / 2.0

    local totalHull = hull and hull.max or 0
    local currentHull = hull and hull.current or 0
    local totalShield = shield and shield.max or 0
    local currentShield = shield and shield.current or 0
    local shieldRegen = shield and (shield.regen or shield.regenRate) or 0
    local totalEffectiveHP = totalHull + totalShield

    local survivalLines = {}
    table.insert(survivalLines, string.format("Hull: %d / %d", math.floor(currentHull), math.floor(totalHull)))
    if totalShield > 0 then
        table.insert(survivalLines, string.format("Shield: %d / %d", math.floor(currentShield), math.floor(totalShield)))
        table.insert(survivalLines, string.format("Shield Regen: %.1f /s", shieldRegen))
    else
        table.insert(survivalLines, "Shield: None equipped")
    end
    table.insert(survivalLines, string.format("Effective HP: %d", math.floor(totalEffectiveHP)))

    local typicalEnemyDPS = 5
    if totalEffectiveHP > 0 and typicalEnemyDPS > 0 then
        table.insert(survivalLines, string.format("Est. Survival: %.0fs vs %d DPS", totalEffectiveHP / typicalEnemyDPS, typicalEnemyDPS))
    end

    local combatLines = {}
    if turret and turret.moduleName and turret.moduleName ~= "" then
        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule then
            local turretDPS = turretModule.DPS or 0
            local effectiveDPS = turretDPS
            if not turretModule.CONTINUOUS then
                local cooldown = turretModule.COOLDOWN or 1
                effectiveDPS = turretDPS / math.max(cooldown, 1)
            end

            table.insert(combatLines, string.format("Weapon: %s", turretModule.NAME or turret.moduleName))
            table.insert(combatLines, string.format("Damage: %.0f", turretDPS))
            table.insert(combatLines, string.format("Sustained DPS: %.1f", effectiveDPS))

            local optimalRange = turretModule.FALLOFF_START or turretModule.RANGE
            local falloffEnd = turretModule.FALLOFF_END or turretModule.ZERO_DAMAGE_RANGE
            if optimalRange and falloffEnd then
                table.insert(combatLines, string.format("Optimal Range: %dm", optimalRange))
                table.insert(combatLines, string.format("Falloff Ends: %dm", falloffEnd))
            elseif turretModule.RANGE then
                table.insert(combatLines, string.format("Range: %dm", turretModule.RANGE))
            end
        else
            table.insert(combatLines, string.format("Weapon: %s", turret.moduleName))
            table.insert(combatLines, "Module data unavailable")
        end
    else
        table.insert(combatLines, "No turret equipped")
    end

    local movementLines = {}
    table.insert(movementLines, string.format("Mass: %.1f", mass))
    table.insert(movementLines, string.format("Max Velocity: %.0f u/s", maxVelocity))
    table.insert(movementLines, string.format("Acceleration: %.0f u/s²", acceleration))

    local energyLines = {}
    if energy then
        table.insert(energyLines, string.format("Energy: %d / %d", math.floor(energy.current or 0), math.floor(energy.max or 0)))
        table.insert(energyLines, string.format("Regen: %.1f /s", energy.regenRate or 0))
    else
        table.insert(energyLines, "No generator installed")
    end

    local sections = {
        { title = "Combat", lines = combatLines },
        { title = "Survival", lines = survivalLines },
        { title = "Movement", lines = movementLines },
        { title = "Energy", lines = energyLines }
    }

    return droneId, sections
end

local function drawSection(sectionX, sectionY, sectionW, title, lines, alpha)
    local lineCount = #lines
    local baseHeight = 36
    local lineSpacing = 18
    local sectionH = baseHeight + lineCount * lineSpacing

    love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.9)
    love.graphics.rectangle('fill', sectionX, sectionY, sectionW, sectionH, 6, 6)

    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', sectionX, sectionY, sectionW, sectionH, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.printf(title, sectionX + 14, sectionY + 10, sectionW - 28, 'left')

    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    local textY = sectionY + 34
    for _, line in ipairs(lines) do
        love.graphics.printf(line, sectionX + 18, textY, sectionW - 36, 'left')
        textY = textY + lineSpacing
    end

    return sectionH
end

function StatsWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.isOpen or not self.position then return end

    local alpha = 1
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height

    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    local contentX = x + 16
    local contentY = y + Theme.window.topBarHeight + 16
    local contentW = w - 32

    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.printf("Ship Statistics", contentX, contentY - 6, contentW, 'left')

    local _, sections = gatherShipData()
    local sectionY = contentY + 24

    for _, section in ipairs(sections) do
        local sectionHeight = drawSection(contentX, sectionY, contentW, section.title, section.lines, alpha)
        sectionY = sectionY + sectionHeight + 12
    end

    local bottomY = y + h - Theme.window.bottomBarHeight + 12
    love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha * 0.8)
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.printf("Stats update automatically when modules change.", contentX, bottomY, contentW, 'left')
end

return StatsWindow
