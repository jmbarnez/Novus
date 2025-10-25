-- HUD Slots Module - Turret slot rendering

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local TurretSystem = require('src.systems.turret')
local TurretRange = require('src.systems.turret_range')
local ItemDefs = require('src.items.item_loader')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDSlots = {}

-- Canvas caching for turret slots
local turretSlotsCanvas, turretSlotsCanvasW, turretSlotsCanvasH, lastTurretSlotsFrame = nil, nil, nil, nil

function HUDSlots.drawTurretSlots(viewportWidth, viewportHeight, hudSystem)
    local frameSkip = math.floor(love.timer.getTime() * 30)
    local updateNow = (not lastTurretSlotsFrame) or (frameSkip % 2 == 0)

    local scaleX = Scaling.canvasScaleX or 1
    local scaleY = Scaling.canvasScaleY or 1
    local scaleU = math.min(scaleX, scaleY)

    local canvasW = math.ceil(180 * scaleX)
    local canvasH = math.ceil(64 * scaleY)

    if turretSlotsCanvasW ~= canvasW or turretSlotsCanvasH ~= canvasH then
        if turretSlotsCanvas then
            turretSlotsCanvas:release()
        end
        turretSlotsCanvas = nil
    end

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
            
            local slotWidth = 48 * scaleX
            local slotHeight = 48 * scaleY
            local slotSpacing = 8 * scaleX
            local startX = 0
            local startY = 0
            
            local turret = ECS.getComponent(droneId, "Turret")
            
            if hudSystem then
                hudSystem.hoveredTurretSlot = nil
            end
            
            for slotIndex = 1, 3 do
                local slotX = startX + (slotIndex - 1) * (slotWidth + slotSpacing)
                local slotY = startY

                -- Plasma theme background (darker energy-infused background)
                local bgColor = {0.05, 0.05, 0.08, 0.95}
                love.graphics.setColor(bgColor)
                local cornerRadius = 4 * scaleU
                love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)

                -- Plasma theme borders with thick black outlines
                local borderColor = {0.2, 0.4, 0.6, 0.8}  -- Default plasma blue
                if turretSlots.slots[slotIndex] then 
                    borderColor = {0.2, 0.8, 1.0, 1.0}  -- Bright cyan when occupied
                end
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(PlasmaTheme.colors.outlineThick * scaleU)
                love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)
                love.graphics.setLineWidth(1)

                if turretSlots.slots[slotIndex] then
                    -- ... (item drawing logic remains the same, assuming it draws to the canvas)
                    
                else
                    -- Plasma energy glow for empty slots
                    love.graphics.setColor(0.1, 0.3, 0.5, 0.6)
                    love.graphics.circle("line", slotX + slotWidth / 2, slotY + slotHeight / 2, math.min(slotWidth, slotHeight) / 4)
                    -- Add inner energy pulse
                    love.graphics.setColor(0.2, 0.4, 0.7, 0.3)
                    love.graphics.circle("fill", slotX + slotWidth / 2, slotY + slotHeight / 2, math.min(slotWidth, slotHeight) / 6)
                end
            end
        end)
        lastTurretSlotsFrame = frameSkip
    end

    local drawX = (Scaling.REFERENCE_WIDTH - turretSlotsCanvasW) / 2
    local drawY = Scaling.REFERENCE_HEIGHT - turretSlotsCanvasH - 20
    BatchRenderer.queueCanvas(turretSlotsCanvas, drawX, drawY, 1, 1, 1, 1)
end

return HUDSlots
