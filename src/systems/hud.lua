---@diagnostic disable: undefined-global
-- HUD System - Coordinates all HUD rendering subsystems
-- Delegates to specialized HUD modules for different HUD elements

local HUDStats = require('src.systems.hud.stats')
local HUDTargeting = require('src.systems.hud.targeting')
local HUDHotbar = require('src.systems.hud.hotbar')
local StatusEffectsHUD = require('src.systems.hud.status_effects')
local Minimap = require('src.systems.hud.minimap')
local Tooltips = require('src.ui.tooltips')
local TargetHUD = require('src.systems.hud.target_hud')
local ConstructionButton = require('src.ui.construction_button')
local QuestOverlay = require('src.ui.quest_overlay')
-- WarpGateHUD overlay removed; only world-space tooltip remains

local HUDSystem = {
    name = "HUDSystem",
    visible = true,
    hoveredHotbarSlot = nil
}

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

function HUDSystem.update(dt)
    -- Update target HUD detection
    TargetHUD.update()
    ConstructionButton.update(dt)
end

function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080
    
    -- Note: Enemy health bars are now drawn earlier in RenderSystem to ensure they render behind UI windows
    
    -- Draw HUD elements directly to screen (no canvas, no shader effects)
    HUDStats.drawPlayerVitals(viewportWidth, viewportHeight)
    StatusEffectsHUD.drawStatusEffects(viewportWidth, viewportHeight)
    HUDHotbar.drawHotbar(viewportWidth, viewportHeight, HUDSystem)
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
    local slot = HUDSystem.hoveredHotbarSlot
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

    -- Warp gate HUD overlay removed; only world-space tooltip remains

end

function HUDSystem.mousepressed(x, y, button)
    if not HUDSystem.visible then
        return false
    end
    if HUDHotbar.mousepressed and HUDHotbar.mousepressed(x, y, button) then
        return true
    end
    return false
end

function HUDSystem.mousereleased(x, y, button)
    if not HUDSystem.visible then
        return false
    end
    if HUDHotbar.mousereleased and HUDHotbar.mousereleased(x, y, button) then
        return true
    end
    return false
end

function HUDSystem.mousemoved(x, y, dx, dy, isTouch)
    if not HUDSystem.visible then
        return
    end
    if HUDHotbar.mousemoved then
        HUDHotbar.mousemoved(x, y, dx, dy, isTouch)
    end
end

return HUDSystem
