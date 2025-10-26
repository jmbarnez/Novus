---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local ECS = require('src.ecs')

local StatsWindow = WindowBase:new{
    width = 500,
    height = 520,
    isOpen = false
}

function StatsWindow:openAt(x, y)
    self.position = { x = x, y = y }
    self:setOpen(true)
end

function StatsWindow:openCenteredIn(parent)
    if not parent or not parent.position then return end
    local px, py = parent.position.x, parent.position.y
    local pw, ph = parent.width, parent.height
    local sx = px + math.max(16, (pw - self.width) / 2)
    local sy = py + math.max(16, (ph - self.height) / 4)
    self.position = { x = sx, y = sy }
    self:setOpen(true)
end

function StatsWindow:getOpen()
    return self.isOpen
end

function StatsWindow:draw()
    if not self.isOpen or not self.position then return end
    local x, y = self.position.x, self.position.y
    local alpha = 1

    WindowBase.draw(self)

    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.printf("Ship Stats", x + 12, y + 8, self.width - 24, "left")

    -- Gather detailed stats from the controlled ship
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")
    local physics = ECS.getComponent(droneId, "Physics")
    local turret = ECS.getComponent(droneId, "Turret")
    local Constants = require('src.constants')
    local TurretRegistry = require('src.turret_registry')

    -- Calculate derived stats
    local mass = physics and physics.mass or 1
    local baseMaxVelocity = Constants.player_max_speed
    local maxVelocity = baseMaxVelocity / mass
    local acceleration = maxVelocity / 2.0
    local totalEffectiveHP = (hull and hull.max or 0) + (shield and shield.max or 0)
    local survivalTime = 0
    if totalEffectiveHP > 0 then
        local typicalEnemyDPS = 5
        survivalTime = totalEffectiveHP / typicalEnemyDPS
    end

    -- Calculate weapon stats
    local turretDPS = 0
    local baseDPS = 0
    local effectiveDPS = 0
    local optimalRange = nil
    local falloffEnd = nil
    local zeroRange = nil

    if turret and turret.moduleName and turret.moduleName ~= "" then
        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule then
            turretDPS = turretModule.DPS or 0
            if turretModule.CONTINUOUS then
                baseDPS = turretDPS
                effectiveDPS = baseDPS
            else
                local turretCooldown = turretModule.COOLDOWN or 1
                baseDPS = turretDPS / math.max(turretCooldown, 1)
                effectiveDPS = baseDPS
            end
            optimalRange = turretModule.FALLOFF_START
            falloffEnd = turretModule.FALLOFF_END or turretModule.ZERO_DAMAGE_RANGE
            zeroRange = turretModule.ZERO_DAMAGE_RANGE or falloffEnd
        end
    end

    local contentY = y + 44
    local sectionHeight = 100
    local sectionWidth = self.width - 24
    local sectionX = x + 12

    -- COMBAT SECTION
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
    love.graphics.rectangle("fill", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
    love.graphics.rectangle("line", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.printf("COMBAT", sectionX + 5, contentY + 8, sectionWidth - 10, "left")

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    local statY = contentY + 26
    love.graphics.printf(string.format("Damage: %.0f", turretDPS), sectionX + 8, statY, sectionWidth - 16, "left")
    statY = statY + 16
    love.graphics.printf(string.format("DPS: %.1f", effectiveDPS), sectionX + 8, statY, sectionWidth - 16, "left")
    statY = statY + 16

    if optimalRange and falloffEnd then
        love.graphics.printf(string.format("Optimal: %dm", optimalRange), sectionX + 8, statY, sectionWidth - 16, "left")
        statY = statY + 16
        love.graphics.printf(string.format("Falloff end: %dm", falloffEnd), sectionX + 8, statY, sectionWidth - 16, "left")
        statY = statY + 16
        if zeroRange and zeroRange > 0 then
            love.graphics.printf(string.format("Max effective: %dm", zeroRange), sectionX + 8, statY, sectionWidth - 16, "left")
            statY = statY + 16
        end

        -- Sample DPS calculations
        local function sampleDPSAt(distance)
            if not optimalRange or not falloffEnd then return effectiveDPS end
            if distance <= optimalRange then return effectiveDPS end
            if distance >= falloffEnd then return 0 end
            local falloffRange = falloffEnd - optimalRange
            local falloffProgress = (distance - optimalRange) / falloffRange
            local multiplier = math.max(0, 1.0 - falloffProgress)
            return effectiveDPS * multiplier
        end

        local sampleOptimal = sampleDPSAt(optimalRange)
        local sampleMid = sampleDPSAt((optimalRange + falloffEnd) / 2)
        love.graphics.printf(string.format("DPS @ optimal: %.1f", sampleOptimal), sectionX + 8, statY, sectionWidth - 16, "left")
        statY = statY + 16
        love.graphics.printf(string.format("DPS @ mid-falloff: %.1f", sampleMid), sectionX + 8, statY, sectionWidth - 16, "left")
    else
        local turretRange = turret and (turret.moduleName and TurretRegistry.getModule(turret.moduleName) and TurretRegistry.getModule(turret.moduleName).RANGE) or 0
        love.graphics.printf(string.format("Range: %d", turretRange or 0), sectionX + 8, statY, sectionWidth - 16, "left")
    end

    contentY = contentY + sectionHeight + 10

    -- SURVIVAL SECTION
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
    love.graphics.rectangle("fill", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
    love.graphics.rectangle("line", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.printf("SURVIVAL", sectionX + 5, contentY + 8, sectionWidth - 10, "left")

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    statY = contentY + 26
    love.graphics.printf(string.format("Eff. HP: %d", totalEffectiveHP), sectionX + 8, statY, sectionWidth - 16, "left")
    statY = statY + 16
    if shield and shield.max > 0 then
        love.graphics.printf(string.format("Shield: +%d", shield.max), sectionX + 8, statY, sectionWidth - 16, "left")
        statY = statY + 16
        love.graphics.printf(string.format("Regen: %.1f/s", shield.regenRate or 0), sectionX + 8, statY, sectionWidth - 16, "left")
        statY = statY + 16
    end
    love.graphics.printf(string.format("Uptime: ~%.0fs", survivalTime), sectionX + 8, statY, sectionWidth - 16, "left")

    contentY = contentY + sectionHeight + 10

    -- MOVEMENT SECTION
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
    love.graphics.rectangle("fill", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
    love.graphics.rectangle("line", sectionX, contentY, sectionWidth, sectionHeight, 3, 3)

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.printf("MOVEMENT", sectionX + 5, contentY + 8, sectionWidth - 10, "left")

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    statY = contentY + 26
    love.graphics.printf(string.format("Max Vel: %.0f u/s", maxVelocity), sectionX + 8, statY, sectionWidth - 16, "left")
    statY = statY + 16
    love.graphics.printf(string.format("Accel: %.0f u/s²", acceleration), sectionX + 8, statY, sectionWidth - 16, "left")
    statY = statY + 16
    love.graphics.printf(string.format("Mass: %.1f", mass), sectionX + 8, statY, sectionWidth - 16, "left")

    -- Draw close button in bottom bar
    local btnW, btnH = 84, 28
    local bx = x + (self.width - btnW) / 2
    local by = y + self.height - Theme.window.bottomBarHeight + (Theme.window.bottomBarHeight - btnH) / 2

    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    local hovered = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH
    love.graphics.setColor(hovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', bx, by, btnW, btnH, 6, 6)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(1,1,1,1)
    love.graphics.printf('Close', bx, by + 6, btnW, 'center')
end

function StatsWindow:mousepressed(x, y, button)
    if not self.isOpen or button ~= 1 or not self.position then return false end
    local bx = self.position.x + (self.width - 84) / 2
    local by = self.position.y + self.height - Theme.window.bottomBarHeight + (Theme.window.bottomBarHeight - 28) / 2
    if x >= bx and x <= bx + 84 and y >= by and y <= by + 28 then
        self:setOpen(false)
        return true
    end
    return false
end

return StatsWindow


