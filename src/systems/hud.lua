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

local HUDSystem = {
    name = "HUDSystem",
    visible = true,
    hoveredTurretSlot = nil
}

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080
    
    -- Draw enemy health bars on screen (before UI, so they render behind)
    HUDBars.drawEnemyHealthBars(viewportWidth, viewportHeight)
    HUDBars.drawAsteroidDurabilityBars(viewportWidth, viewportHeight)
    HUDBars.drawWreckageDurabilityBars(viewportWidth, viewportHeight)
    
    -- Draw HUD elements directly to screen (no canvas, no shader effects)
    HUDStats.drawHullShieldBar(viewportWidth, viewportHeight)
    HUDStats.drawEnergyBar(viewportWidth, viewportHeight)
    HUDSlots.drawTurretSlots(viewportWidth, viewportHeight, HUDSystem)
    if Minimap and Minimap.draw then Minimap.draw() end
    HUDStats.drawSpeedText(viewportWidth, viewportHeight)
    HUDStats.drawFpsCounter(viewportWidth, viewportHeight)
    
    -- Notifications & skills
    local Notifications = require('src.ui.notifications')
    local SkillNotifications = require('src.ui.skill_notifications')
    Notifications.draw(0, 0, 1)
    SkillNotifications.draw()
    
    -- Draw overlays (targeting indicator/crosshair/tooltips)
    HUDTargeting.drawTargetingPanel(viewportWidth, viewportHeight)
    
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
end

return HUDSystem
