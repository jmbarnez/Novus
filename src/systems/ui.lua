---@diagnostic disable: undefined-global
-- UI System - Main UI coordinator with modular components
-- Uses theme system and modular components for clean organization

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local CargoWindow = require('src.ui.cargo_window')
local Tooltips = require('src.ui.tooltips')
local Dialogs = require('src.ui.dialogs')
local Notifications = require('src.ui.notifications')
local SkillNotifications = require('src.ui.skill_notifications')
local Scaling = require('src.scaling')
-- Hotbar removed

-- UI System main table
local UISystem = {
    name = "UISystem",
    priority = 10
}

-- Track whether the UI has captured (consumed) pointer input
local mouseCaptured = false

function UISystem.captureMouse()
    mouseCaptured = true
end

function UISystem.releaseMouse()
    mouseCaptured = false
end

function UISystem.isMouseCaptured()
    return mouseCaptured
end

-- Interactive registry for UI elements that should capture pointer input
local interactiveOrder = {}
local interactiveMap = {}

-- Register an interactive area with a hit-test and optional click handler
-- name (string), hitTestFn(x,y,button) -> boolean, clickHandlerFn(x,y,button) -> boolean
-- Note: hitTestFn and clickHandlerFn receive scaled coordinates (reference space)
function UISystem.registerInteractive(name, hitTestFn, clickHandlerFn)
    if interactiveMap[name] then
        -- replace existing
        interactiveMap[name] = {hit = hitTestFn, handler = clickHandlerFn}
        return
    end
    interactiveMap[name] = {hit = hitTestFn, handler = clickHandlerFn}
    table.insert(interactiveOrder, name)
end

function UISystem.unregisterInteractive(name)
    interactiveMap[name] = nil
    for i, n in ipairs(interactiveOrder) do
        if n == name then
            table.remove(interactiveOrder, i)
            break
        end
    end
end

-- Register default interactive elements
-- Confirmation dialog
UISystem.registerInteractive('confirm_dialog', function(x, y, button)
    return Dialogs.confirmDialog ~= nil and true or false
end, function(x, y, button)
    return Dialogs.handleConfirmDialogClick(x, y, button)
end)

-- Context menu
UISystem.registerInteractive('context_menu', function(x, y, button)
    return Dialogs.contextMenu ~= nil and Dialogs.contextMenu.displayX and Dialogs.contextMenu.displayY and
           x >= (Dialogs.contextMenu.displayX or Dialogs.contextMenu.x) and x <= (Dialogs.contextMenu.displayX or Dialogs.contextMenu.x) + 100 and
           y >= (Dialogs.contextMenu.displayY or Dialogs.contextMenu.y) and y <= (Dialogs.contextMenu.displayY or Dialogs.contextMenu.y) + 28
end, function(x, y, button)
    return Dialogs.handleContextMenuClick(x, y, button)
end)

-- Cargo window
UISystem.registerInteractive('cargo_window', function(x, y, button)
    return CargoWindow.isOpen and CargoWindow.position and x >= CargoWindow.position.x and x <= CargoWindow.position.x + CargoWindow.width
           and y >= CargoWindow.position.y and y <= CargoWindow.position.y + CargoWindow.height
end, function(x, y, button)
    -- Right-click to open context menu if hovering an item
    if button == 2 and CargoWindow.hoveredItemSlot then
        Dialogs.contextMenu = {itemId = CargoWindow.hoveredItemSlot.itemId, x = x, y = y}
        return true
    end
    CargoWindow:mousepressed(x, y, button)
    return true
end)


-- Minimap input capture is now handled by HUD, but we still want UI to eat clicks over minimap
local Minimap = require('src.systems.minimap')
UISystem.registerInteractive('minimap', function(x, y, button)
    return Minimap and Minimap.isPointOver and Minimap.isPointOver(x, y)
end, function(x, y, button)
    -- just consume the click
    return true
end)

-- HUD drawing has been moved to `src.systems.hud`

-- Main draw function
function UISystem.draw(viewportWidth, viewportHeight)
    -- Get viewport dimensions from parameters or canvas
    if not viewportWidth or not viewportHeight then
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        viewportWidth = Constants.screen_width
        viewportHeight = Constants.screen_height
        
        if #canvasEntities > 0 then
            local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
            if canvasComp then
                viewportWidth = canvasComp.width
                viewportHeight = canvasComp.height
            end
        end
    end
    -- viewportWidth/viewportHeight are already canvas (reference) units
    
    -- HUD elements are rendered by the HUD system inside RenderSystem
    
    -- Draw notifications (in screen space)
    Notifications.draw(0, 0, 1)
    
    -- Draw skill notifications (in screen space)
    SkillNotifications.draw()
    
    -- Draw cargo window and related UI
    CargoWindow:draw(viewportWidth, viewportHeight)
    
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
    
    -- Draw tooltip for turret slot
    if CargoWindow.isOpen and CargoWindow.hoveredTurretSlot and not Dialogs.contextMenu and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            CargoWindow.hoveredTurretSlot.itemId,
            CargoWindow.hoveredTurretSlot.itemDef,
            CargoWindow.hoveredTurretSlot.count,
            CargoWindow.hoveredTurretSlot.mouseX,
            CargoWindow.hoveredTurretSlot.mouseY
        )
        -- Not handled by UI
        return false
    end
    return false
end

-- Update function for UI (handles notifications timing)
function UISystem.update(dt)
    Notifications.update(dt)
    SkillNotifications.update(dt)
    CargoWindow:update(dt)
end

-- Key pressed handler
function UISystem.keypressed(key)
    if key == 'tab' or key == 'escape' then
        CargoWindow:toggle()
    end
end

-- Mouse pressed handler
function UISystem.mousepressed(x, y, button)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)
    
    -- Let registered interactive elements handle the click in registration order
    for _, name in ipairs(interactiveOrder) do
        local entry = interactiveMap[name]
        if entry and entry.hit and entry.hit(mx, my, button) then
            local handled = false
            if entry.handler then handled = entry.handler(mx, my, button) end
            if handled then
                UISystem.captureMouse()
                return true
            end
        end
    end

    -- If click is on the minimap, capture it so it doesn't pass to the world
    local Minimap = require('src.systems.minimap')
    if Minimap and Minimap.isPointOver then
        if Minimap.isPointOver(mx, my) then
            UISystem.captureMouse()
            return true
        end
    end
end

-- Mouse released handler
function UISystem.mousereleased(x, y, button)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)
    CargoWindow:mousereleased(mx, my, button)
    -- Release capture on mouse release (assumes left click)
    if button == 1 then
        UISystem.releaseMouse()
    end
end

-- Mouse moved handler
function UISystem.mousemoved(x, y, dx, dy, isTouch)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)
    CargoWindow:mousemoved(mx, my, dx, dy)
end

-- Public API functions
function UISystem.setCargoWindowOpen(state)
    CargoWindow:setOpen(state)
end

function UISystem.toggleCargoWindow()
    CargoWindow:toggle()
end

function UISystem.isCargoWindowOpen()
    return CargoWindow:getOpen()
end

-- Public API for adding skill experience
function UISystem.addSkillExperience(skillName, xpGain)
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then return end
    
    local playerId = playerEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills or not skills.skills[skillName] then return end
    
    local skill = skills.skills[skillName]
    skill.experience = skill.experience + xpGain
    skill.totalXp = skill.totalXp + xpGain
    
    -- Check for level up
    local leveledUp = false
    while skill.experience >= skill.requiredXp do
        skill.experience = skill.experience - skill.requiredXp
        skill.level = skill.level + 1
        skill.requiredXp = math.ceil(skill.requiredXp * 1.1)  -- 10% increase per level
        leveledUp = true
    end
    
    -- Show notification
    local notifData = {
        level = skill.level,
        experience = skill.experience,
        requiredXp = skill.requiredXp,
        levelUp = leveledUp
    }
    SkillNotifications.addNotification(skillName, xpGain, notifData)
end

return UISystem
