---@diagnostic disable: undefined-global
-- HUD System - Coordinates all HUD rendering subsystems
-- Delegates to specialized HUD modules for different HUD elements

local ECS = require('src.ecs')
local HUDStats = require('src.systems.hud.stats')
local HUDTargeting = require('src.systems.hud.targeting')
local HUDSlots = require('src.systems.hud.slots')
local HUDBars = require('src.systems.hud.bars')
local Minimap = require('src.systems.minimap')
local Tooltips = require('src.ui.tooltips')
local TargetHUD = require('src.systems.target_hud')
local ConstructionButton = require('src.ui.construction_button')
local QuestOverlay = require('src.ui.quest_overlay')

local HUDSystem = {
    name = "HUDSystem",
    visible = true,
    hoveredTurretSlot = nil
}

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

function HUDSystem.update(dt)
    -- Update target HUD detection
    TargetHUD.update()
end

function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1600
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 900
    
    -- Note: Enemy health bars are now drawn earlier in RenderSystem to ensure they render behind UI windows
    
    -- Draw HUD elements directly to screen (no canvas, no shader effects)
    HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
    HUDStats.drawEnergyBar(viewportWidth, viewportHeight)
    HUDSlots.drawTurretSlots(viewportWidth, viewportHeight, HUDSystem)
    if Minimap and Minimap.draw then Minimap.draw() end
    HUDStats.drawSpeedText(viewportWidth, viewportHeight)
    HUDStats.drawFpsCounter(viewportWidth, viewportHeight)
    
    -- Notifications & skills
    local Notifications = require('src.ui.notifications')
    Notifications.draw()
    
    -- Draw quest overlay (batched rendering, below minimap)
    QuestOverlay.draw()
    
    -- Draw overlays (targeting indicator/crosshair/tooltips)
    HUDTargeting.drawTargetingPanel(viewportWidth, viewportHeight)
    
    -- Draw target HUD popup (in screen space, same position as skill notifications)
    TargetHUD.drawPopup()
    
    -- Tooltip popup
    local slot = HUDSystem.hoveredTurretSlot
    if slot and type(slot) == "table" and slot.itemId and slot.itemDef and slot.mouseX and slot.mouseY then
        Tooltips.drawItemTooltip(
            slot.itemId,
            slot.itemDef,
            1,
            slot.mouseX,
            slot.mouseY
        )
    end
    -- Always-on ConstructionButton (HUD layer)
    ConstructionButton.draw(viewportWidth, viewportHeight)
end

return HUDSystem
