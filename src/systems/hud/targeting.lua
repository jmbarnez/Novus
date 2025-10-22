-- HUD Targeting Module - Targeting panel display

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')

local HUDTargeting = {}

function HUDTargeting.drawTargetingPanel(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetedEnemy then return end
    local entity = input.targetedEnemy
    local targetPos = ECS.getComponent(entity, "Position")
    local targetHull = ECS.getComponent(entity, "Hull")
    local targetShield = ECS.getComponent(entity, "Shield")
    local targetTurret = ECS.getComponent(entity, "Turret")
    local targetVelocity = ECS.getComponent(entity, "Velocity")
    local playerEntity = input.targetEntity
    local playerPos = playerEntity and ECS.getComponent(playerEntity, "Position")
    
    local panelW, panelH = Scaling.scaleSize(308), Scaling.scaleSize(100)
    local centerX = viewportWidth / 2
    local posX = centerX - panelW / 2
    local posY = Theme.spacing.margin + 8
    
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", posX, posY, panelW, panelH, Theme.spacing.padding * 2)
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", posX, posY, panelW, panelH, Theme.spacing.padding * 2)
    
    local smallFont = Theme.getFont(Theme.fonts.small)
    local normalFont = Theme.getFont(Theme.fonts.normal)
    love.graphics.setFont(normalFont)
    local col1 = posX + Theme.spacing.padding * 2
    local col2 = posX + panelW * 0.54
    local row = posY + Theme.spacing.padding * 1.5
    local rowH = Scaling.scaleSize(18)
    local barW = panelW - Theme.spacing.padding * 4
    local barH = Scaling.scaleSize(22)
    
    local hullVal = targetHull and targetHull.current or 0
    local hullMax = targetHull and targetHull.max or 1
    local shieldVal = (targetShield and targetShield.current) or 0
    local shieldMax = (targetShield and targetShield.max) or 0
    
    local hullRatio = math.min(hullVal / hullMax, 1.0)
    local fillWidth = barW * hullRatio
    local x = col1
    local y = row
    
    PlasmaTheme.drawHealthBar(x, y, barW, barH, hullRatio, false)
    
    if shieldMax > 0 and shieldVal > 0 then
        local sRatio = math.min(shieldVal / shieldMax, 1.0)
        PlasmaTheme.drawHealthBar(x, y, barW, barH, sRatio, true)
    end
    
    local barText
    if shieldMax > 0 then
        barText = string.format("Hull %d/%d   Shield %d/%d", hullVal, hullMax, shieldVal, shieldMax)
    else
        barText = string.format("Hull %d/%d", hullVal, hullMax)
    end
    love.graphics.setFont(smallFont)
    local barTextW = smallFont:getWidth(barText)
    local barTextX = x + (barW - barTextW) / 2
    local barTextY = y + (barH - smallFont:getHeight()) / 2
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(barText, barTextX, barTextY)
    
    row = row + barH + Scaling.scaleY(6)
    love.graphics.setFont(normalFont)
    
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.print("Distance:", col1, row)
    love.graphics.setColor(Theme.colors.textAccent)
    if playerPos and targetPos then
        local dx, dy = targetPos.x - playerPos.x, targetPos.y - playerPos.y
        love.graphics.print(string.format("%.0f u", math.sqrt(dx*dx+dy*dy)), col2, row)
    else
        love.graphics.print("-", col2, row)
    end
    row = row + rowH
    
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.print("Speed:", col1, row)
    love.graphics.setColor(Theme.colors.textAccent)
    if targetVelocity then
        local speed = math.sqrt((targetVelocity.vx or 0)^2 + (targetVelocity.vy or 0)^2)
        love.graphics.print(string.format("%.0f u/s", speed), col2, row)
    else
        love.graphics.print("0 u/s", col2, row)
    end
end

return HUDTargeting

