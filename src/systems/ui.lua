---@diagnostic disable: undefined-global
-- UI System - Main UI coordinator with modular components
-- Uses theme system and modular components for clean organization

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local CargoWindow = require('src.ui.cargo_window')
local Tooltips = require('src.ui.tooltips')
local Dialogs = require('src.ui.dialogs')

-- UI System main table
local UISystem = {
    name = "UISystem"
}

-- Helper function to draw speed indicator
local function drawSpeedIndicator(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Velocity"})
    if #playerEntities == 0 then return end
    
    local velocity = ECS.getComponent(playerEntities[1], "Velocity")
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
    
    local barWidth = Constants.ui_speed_bar_width
    local barHeight = Constants.ui_speed_bar_height
    local x = viewportWidth - barWidth - 20
    local y = viewportHeight - barHeight - 20
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    
    -- Draw speed fill
    local maxSpeed = Constants.player_max_speed
    local speedRatio = math.min(speed / maxSpeed, 1.0)
    love.graphics.setColor(0.2, 0.6, 1.0, 0.9)
    love.graphics.rectangle("fill", x, y, barWidth * speedRatio, barHeight)
    
    -- Draw text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(string.format("Speed: %d", speed), x, y + 5, barWidth, "center")
end

-- Helper function to draw health bar
local function drawHealthBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Health"})
    if #playerEntities == 0 then return end
    
    local health = ECS.getComponent(playerEntities[1], "Health")
    
    local barWidth = Constants.ui_health_bar_width
    local barHeight = Constants.ui_health_bar_height
    local x = 20
    local y = 20
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    
    -- Draw health fill
    local healthRatio = math.min(health.current / health.max, 1.0)
    love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", x, y, barWidth * healthRatio, barHeight)
    
    -- Draw text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(string.format("Hull: %d%%", health.current / health.max * 100), x, y + 5, barWidth, "center")
end

-- Main draw function
function UISystem.draw(viewportWidth, viewportHeight)
    -- Draw HUD elements
    local uiEntities = ECS.getEntitiesWith({"UI"})
    for _, entityId in ipairs(uiEntities) do
        local ui = ECS.getComponent(entityId, "UI")
        if ui.uiType == "hud" then
            drawSpeedIndicator(viewportWidth, viewportHeight)
            drawHealthBar(viewportWidth, viewportHeight)
        end
    end
    
    -- Draw cargo window and related UI
    CargoWindow.draw(viewportWidth, viewportHeight)
    
    -- Draw confirmation dialog if active (highest priority)
    if Dialogs.confirmDialog then
        Dialogs.drawConfirmDialog()
    end
    
    -- Draw context menu if active
    if Dialogs.contextMenu then
        Dialogs.drawContextMenu(Dialogs.contextMenu.x, Dialogs.contextMenu.y)
    end
    
    -- Draw tooltip if hovering over item and no menus are open
    if CargoWindow.isOpen and CargoWindow.hoveredItemSlot and not Dialogs.contextMenu and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            CargoWindow.hoveredItemSlot.itemId,
            CargoWindow.hoveredItemSlot.itemDef,
            CargoWindow.hoveredItemSlot.count,
            CargoWindow.hoveredItemSlot.mouseX,
            CargoWindow.hoveredItemSlot.mouseY
        )
    end
end

-- Key pressed handler
function UISystem.keypressed(key)
    if key == 'tab' or key == 'escape' then
        CargoWindow.toggle()
    end
end

-- Mouse pressed handler
function UISystem.mousepressed(x, y, button)
    -- Handle dialogs first (highest priority)
    if Dialogs.confirmDialog then
        Dialogs.handleConfirmDialogClick(x, y, button)
        return
    end
    
    if Dialogs.contextMenu then
        Dialogs.handleContextMenuClick(x, y, button)
        return
    end
    
    -- Handle cargo window
    if CargoWindow.isOpen then
        -- Right-click on items for context menu
        if button == 2 and CargoWindow.hoveredItemSlot then
            Dialogs.contextMenu = {itemId = CargoWindow.hoveredItemSlot.itemId, x = x, y = y}
            return
        end
        
        CargoWindow.mousepressed(x, y, button)
    end
end

-- Mouse released handler
function UISystem.mousereleased(x, y, button)
    CargoWindow.mousereleased(x, y, button)
end

-- Mouse moved handler
function UISystem.mousemoved(x, y, dx, dy, isTouch)
    CargoWindow.mousemoved(x, y, dx, dy)
end

-- Public API functions
function UISystem.setCargoWindowOpen(state)
    CargoWindow.setOpen(state)
end

function UISystem.toggleCargoWindow()
    CargoWindow.toggle()
end

function UISystem.isCargoWindowOpen()
    return CargoWindow.getOpen()
end

return UISystem
