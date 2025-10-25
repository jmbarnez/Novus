-- HUD Slots Module - Turret slot rendering

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local TurretSystem = require('src.systems.turret')
local TurretRange = require('src.systems.turret_range')
local ItemDefs = require('src.items.item_loader')
local PlasmaTheme = require('src.ui.plasma_theme')

local HUDSlots = {}

-- Canvas caching for turret slots
local turretSlotsCanvas, turretSlotsCanvasW, turretSlotsCanvasH, lastTurretSlotsFrame = nil, nil, nil, nil

function HUDSlots.drawTurretSlots(viewportWidth, viewportHeight, hudSystem)
    local frameSkip = math.floor(love.timer.getTime() * 30)
    local updateNow = (not lastTurretSlotsFrame) or (frameSkip % 2 == 0)
    local canvasW, canvasH = Scaling.scaleSize(180), Scaling.scaleSize(64)
    turretSlotsCanvasW, turretSlotsCanvasH = canvasW, canvasH
    if not turretSlotsCanvas then
        turretSlotsCanvas = love.graphics.newCanvas(canvasW, canvasH)
    end

    if updateNow then
        turretSlotsCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            
            local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
            if #playerEntities == 0 then return end
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if not input or not input.targetEntity then return end
            
            local droneId = input.targetEntity
            local turretSlots = ECS.getComponent(droneId, "TurretSlots")
            if not turretSlots then return end
            
            local slotSize = Scaling.scaleSize(48)
            local slotSpacing = Scaling.scaleSize(8)
            local startX = 0
            local startY = 0
            
            local turret = ECS.getComponent(droneId, "Turret")
            
            if hudSystem then
                hudSystem.hoveredTurretSlot = nil
            end
            
            for slotIndex = 1, 3 do
                local slotX = startX + (slotIndex - 1) * (slotSize + slotSpacing)
                local slotY = startY
                
                -- Plasma theme background (darker energy-infused background)
                local bgColor = {0.05, 0.05, 0.08, 0.95}
                love.graphics.setColor(bgColor)
                love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
                
                -- Plasma theme borders with thick black outlines
                local borderColor = {0.2, 0.4, 0.6, 0.8}  -- Default plasma blue
                if turretSlots.slots[slotIndex] then 
                    borderColor = {0.2, 0.8, 1.0, 1.0}  -- Bright cyan when occupied
                end
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(PlasmaTheme.colors.outlineThick)
                love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
                love.graphics.setLineWidth(1)
                
                if turretSlots.slots[slotIndex] then
                    local itemId = turretSlots.slots[slotIndex]
                    local itemDef = ItemDefs[itemId]
                    if itemDef and itemDef.module and itemDef.module.draw then
                        love.graphics.setColor(1, 1, 1, 1)
                        local ok = pcall(itemDef.module.draw, itemDef.module, slotX + slotSize / 2, slotY + slotSize / 2)
                        if not ok then
                            love.graphics.setColor(0.5, 0.5, 0.8, 1)
                            love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
                        end
                    elseif itemDef and itemDef.draw then
                        love.graphics.setColor(1, 1, 1, 1)
                        itemDef:draw(slotX + slotSize / 2, slotY + slotSize / 2)
                    else
                        love.graphics.setColor(0.5, 0.5, 0.8, 1)
                        love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
                    end
                    
                    if slotIndex == 1 and turret then
                        local moduleName = turret.moduleName
                        local module = moduleName and TurretSystem.turretModules[moduleName]
                        local isLaserTurret = moduleName == "mining_laser" or moduleName == "combat_laser" or moduleName == "salvage_laser"
                        if module and module.CONTINUOUS and isLaserTurret then
                            local heat = turret.heat
                            if heat then
                                local heatVal = (heat.current or 0)
                                local maxHeat = module.MAX_HEAT or 10
                                local isInCooldown = heatVal >= maxHeat
                                
                                if isInCooldown then
                                    local cooldownTimer = heat.cooldownTimer or 0
                                    local blinkPhase = math.floor((cooldownTimer * 4)) % 2
                                    if blinkPhase == 0 then
                                        -- Plasma energy overheat warning (electric pink/magenta)
                                        love.graphics.setColor(1.0, 0.2, 0.5, 0.8)
                                        local pad = math.max(2, math.floor(slotSize * 0.08))
                                        local innerH = slotSize - pad * 2
                                        local innerW = slotSize - pad * 2
                                        love.graphics.rectangle("fill", slotX + pad, slotY + pad, innerW, innerH, 3, 3)
                                    end
                                else
                                    local heatRatio = heatVal / maxHeat
                                    local pad = math.max(2, math.floor(slotSize * 0.08))
                                    local innerH = slotSize - pad * 2
                                    local innerW = slotSize - pad * 2
                                    local overlayInnerWidth = math.floor(innerW * heatRatio)
                                    -- Plasma energy heat buildup (orange to red energy)
                                    love.graphics.setColor(1.0, 0.4, 0.1, 0.5)
                                    if overlayInnerWidth > 0 then
                                        love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                                    end
                                end
                            end
                        elseif module then
                            local moduleCooldown = TurretRange.getFireCooldown(moduleName)
                            local currentTime = love.timer.getTime()
                            local timeSinceLastFire = currentTime - (turret.lastFireTime or 0)
                            local cooldownRatio = math.max(0, math.min(timeSinceLastFire / moduleCooldown, 1.0))
                            local pad = math.max(2, math.floor(slotSize * 0.08))
                            local innerH = slotSize - pad * 2
                            local innerW = slotSize - pad * 2
                            local overlayInnerWidth = math.floor(innerW * cooldownRatio)
                            -- Plasma energy cooldown (bright cyan energy)
                            love.graphics.setColor(0.2, 0.8, 1.0, 0.4)
                            if overlayInnerWidth > 0 then
                                love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                            end
                        end
                    end
                else
                    -- Plasma energy glow for empty slots
                    love.graphics.setColor(0.1, 0.3, 0.5, 0.6)  -- Subtle plasma blue glow
                    love.graphics.circle("line", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 4)
                    -- Add inner energy pulse
                    love.graphics.setColor(0.2, 0.4, 0.7, 0.3)
                    love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 6)
                end
            end
        end)
        lastTurretSlotsFrame = frameSkip
    end
    
    local drawX = (viewportWidth - turretSlotsCanvasW) / 2
    local drawY = viewportHeight - turretSlotsCanvasH - Scaling.scaleY(20)
    love.graphics.setColor(1, 1, 1, 1)
    local scale = Scaling.getScale()
    love.graphics.draw(turretSlotsCanvas, drawX, drawY, 0, scale, scale)
end

return HUDSlots

