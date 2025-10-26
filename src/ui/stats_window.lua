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

StatsWindow.scrollOffset = 0
StatsWindow.maxScroll = 0

function StatsWindow:getOpen()
    return self.isOpen
end

function StatsWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if state then
        self.scrollOffset = 0
    end
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

local function calculateSectionHeight(lines)
    local baseHeight = 36
    local lineSpacing = 18
    return baseHeight + (#lines) * lineSpacing
end

function StatsWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end

    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight

    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    local contentPadding = 16
    local contentAreaX = x + contentPadding
    local contentAreaW = w - contentPadding * 2
    local contentAreaY = y + topBarH + 4
    local contentAreaH = math.max(0, h - topBarH - bottomBarH - 8)
    local contentOriginY = contentAreaY + 8

    local titleFont = Theme.getFontBold(Theme.fonts.title)
    local tinyFont = Theme.getFont(Theme.fonts.tiny)
    local titleHeight = titleFont:getHeight()
    local titleSpacing = 16
    local sectionSpacing = 12
    local footerSpacing = 10
    local footerHeight = tinyFont:getHeight()

    local _, sections = gatherShipData()

    local totalHeight = titleHeight + titleSpacing
    for index, section in ipairs(sections) do
        totalHeight = totalHeight + calculateSectionHeight(section.lines)
        if index < #sections then
            totalHeight = totalHeight + sectionSpacing
        end
    end
    totalHeight = totalHeight + footerSpacing + footerHeight

    local contentBottom = contentOriginY + totalHeight
    local visibleBottom = contentAreaY + contentAreaH
    self.maxScroll = math.max(0, contentBottom - visibleBottom)
    self.scrollOffset = math.max(0, math.min(self.scrollOffset or 0, self.maxScroll))
    local scrollY = self.scrollOffset

    love.graphics.push('all')
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    local cursorY = contentOriginY - scrollY
    love.graphics.printf("Ship Statistics", contentAreaX, cursorY, contentAreaW, 'left')
    cursorY = cursorY + titleHeight + titleSpacing

    for index, section in ipairs(sections) do
        local sectionHeight = drawSection(contentAreaX, cursorY, contentAreaW, section.title, section.lines, alpha)
        cursorY = cursorY + sectionHeight
        if index < #sections then
            cursorY = cursorY + sectionSpacing
        end
    end

    cursorY = cursorY + footerSpacing
    love.graphics.setFont(tinyFont)
    love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha * 0.8)
    love.graphics.printf("Stats update automatically when modules change.", contentAreaX, cursorY, contentAreaW, 'left')

    love.graphics.pop()
end

function StatsWindow:wheelmoved(x, y)
    if not self.isOpen or y == 0 then return false end

    local uiMx, uiMy
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        uiMx, uiMy = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        uiMx, uiMy = Scaling.toUI(love.mouse.getPosition())
    end

    local contentTop = (self.position and self.position.y or 0) + Theme.window.topBarHeight
    local contentBottom = (self.position and self.position.y or 0) + self.height - Theme.window.bottomBarHeight
    local contentLeft = (self.position and self.position.x or 0)
    local contentRight = contentLeft + self.width

    if uiMx >= contentLeft and uiMx <= contentRight and uiMy >= contentTop and uiMy <= contentBottom then
        local scrollSpeed = 30
        local newOffset = (self.scrollOffset or 0) - y * scrollSpeed
        self.scrollOffset = math.max(0, math.min(newOffset, self.maxScroll or 0))
        return true
    end

    return false
end

return StatsWindow
