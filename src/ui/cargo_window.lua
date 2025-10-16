-- UI Cargo Window Module - Handles cargo inventory display and interaction
-- Modular cargo window with theme support

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')

local CargoWindow = {
    isOpen = false,
    position = nil,  -- {x, y}
    isDragging = false,
    dragOffset = {x = 0, y = 0},
    closeButtonRect = nil,
    hoveredItemSlot = nil,
}

local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 500
local TOP_BAR_HEIGHT = Theme.window.topBarHeight
local BOTTOM_BAR_HEIGHT = Theme.window.bottomBarHeight

function CargoWindow.toggle()
    CargoWindow.isOpen = not CargoWindow.isOpen
end

function CargoWindow.setOpen(state)
    CargoWindow.isOpen = state
end

function CargoWindow.getOpen()
    return CargoWindow.isOpen
end

-- Draw the cargo window
function CargoWindow.draw(viewportWidth, viewportHeight)
    if not CargoWindow.isOpen then return end
    
    local cargoEntities = ECS.getEntitiesWith({"InputControlled", "Cargo"})
    if #cargoEntities == 0 then return end
    
    local playerId = cargoEntities[1]
    local cargo = ECS.getComponent(playerId, "Cargo")
    if not cargo then return end
    
    local currency = ECS.getComponent(playerId, "Currency")
    
    -- Initialize position
    if not CargoWindow.position then
        CargoWindow.position = {
            x = (viewportWidth - WINDOW_WIDTH) / 2,
            y = (viewportHeight - WINDOW_HEIGHT) / 2
        }
    end
    
    local x, y = CargoWindow.position.x, CargoWindow.position.y
    
    -- Draw 3D border
    Theme.draw3DBorder(x, y, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    -- Draw top bar
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", x, y, WINDOW_WIDTH, TOP_BAR_HEIGHT)
    
    -- Draw close button (red circle)
    local closeSize = 20
    local closeX = x + WINDOW_WIDTH - closeSize - 10
    local closeY = y + (TOP_BAR_HEIGHT - closeSize) / 2
    local mx, my = love.mouse.getPosition()
    local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
    
    local closeColor = closeHover and Theme.colors.buttonCloseHover or Theme.colors.buttonClose
    love.graphics.setColor(closeColor)
    love.graphics.circle("fill", closeX + closeSize / 2, closeY + closeSize / 2, closeSize / 2)
    
    -- Draw X on close button
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.line(closeX + 6, closeY + 6, closeX + closeSize - 6, closeY + closeSize - 6)
    love.graphics.line(closeX + closeSize - 6, closeY + 6, closeX + 6, closeY + closeSize - 6)
    love.graphics.setLineWidth(1)
    
    CargoWindow.closeButtonRect = {x = closeX, y = closeY, w = closeSize, h = closeSize}
    
    -- Draw bottom bar
    local bottomY = y + WINDOW_HEIGHT - BOTTOM_BAR_HEIGHT
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", x, bottomY, WINDOW_WIDTH, BOTTOM_BAR_HEIGHT)
    
    -- Draw cargo info text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.normal))
    local itemCount = 0
    for _, v in pairs(cargo.items) do itemCount = itemCount + v end
    local capText = string.format("Cargo: %d / %d", itemCount, cargo.capacity or 0)
    love.graphics.print(capText, x + 12, bottomY + 5)
    
    local currencyText = currency and string.format("Credits: %d", currency.amount or 0) or ""
    love.graphics.print(currencyText, x + WINDOW_WIDTH - 140, bottomY + 5)
    
    -- Draw items grid
    CargoWindow.drawItemsGrid(x, y, cargo)
end

-- Draw items in a grid layout
function CargoWindow.drawItemsGrid(windowX, windowY, cargo)
    local iconSize = Theme.spacing.iconSize
    local padding = Theme.spacing.iconGridPadding
    local gridTop = windowY + TOP_BAR_HEIGHT + padding
    local cols = math.floor((WINDOW_WIDTH - padding * 2) / (iconSize + padding))
    
    local mx, my = love.mouse.getPosition()
    CargoWindow.hoveredItemSlot = nil
    
    local ItemDefs = require('src.items.item_loader')
    local i = 0
    
    for itemId, count in pairs(cargo.items) do
        local row = math.floor(i / cols)
        local col = i % cols
        local iconX = windowX + padding + col * (iconSize + padding)
        local iconY = gridTop + row * (iconSize + padding)
        
        -- Check hover
        local isHovering = mx >= iconX and mx <= iconX + iconSize and my >= iconY and my <= iconY + iconSize
        
        local itemDef = ItemDefs[itemId]
        local color = itemDef and itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
        
        -- Draw item circle (brightened on hover)
        if isHovering then
            love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, color[4])
            CargoWindow.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my}
        else
            love.graphics.setColor(color)
        end
        love.graphics.circle("fill", iconX + iconSize / 2, iconY + iconSize / 2, iconSize / 2)
        
        -- Draw stack count
        if count > 1 then
            love.graphics.setColor(Theme.colors.textPrimary)
            love.graphics.setFont(love.graphics.newFont(Theme.fonts.small))
            love.graphics.printf(tostring(count), iconX, iconY + iconSize - 8, iconSize, "center")
            love.graphics.setFont(love.graphics.newFont(Theme.fonts.title))
        end
        
        i = i + 1
    end
end

-- Handle mouse pressed events
function CargoWindow.mousepressed(x, y, button)
    if not CargoWindow.isOpen then return end
    
    -- Check close button
    if CargoWindow.closeButtonRect and button == 1 then
        if x >= CargoWindow.closeButtonRect.x and x <= CargoWindow.closeButtonRect.x + CargoWindow.closeButtonRect.w
           and y >= CargoWindow.closeButtonRect.y and y <= CargoWindow.closeButtonRect.y + CargoWindow.closeButtonRect.h then
            CargoWindow.isOpen = false
            return
        end
    end
    
    -- Check top bar drag
    if x >= CargoWindow.position.x and x <= CargoWindow.position.x + WINDOW_WIDTH
       and y >= CargoWindow.position.y and y <= CargoWindow.position.y + TOP_BAR_HEIGHT and button == 1 then
        CargoWindow.isDragging = true
        CargoWindow.dragOffset.x = x - CargoWindow.position.x
        CargoWindow.dragOffset.y = y - CargoWindow.position.y
    end
end

-- Handle mouse released events
function CargoWindow.mousereleased(x, y, button)
    if button == 1 then
        CargoWindow.isDragging = false
    end
end

-- Handle mouse moved events
function CargoWindow.mousemoved(x, y, dx, dy)
    if CargoWindow.isDragging and CargoWindow.position then
        CargoWindow.position.x = x - CargoWindow.dragOffset.x
        CargoWindow.position.y = y - CargoWindow.dragOffset.y
    end
end

return CargoWindow
