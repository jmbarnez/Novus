-- UI Dialogs Module - Handles context menus and confirmation dialogs with theme support
-- Modular dialog system for user confirmations

local Theme = require('src.ui.theme')
local ECS = require('src.ecs')

local Dialogs = {
    contextMenu = nil,      -- {itemId, x, y}
    confirmDialog = nil,    -- {itemId, yesRect, noRect}
}

-- Draw context menu
function Dialogs.drawContextMenu(x, y)
    if not Dialogs.contextMenu then return end
    
    local options = {"Delete"}
    local optionH = 28
    local optionW = 100
    local menuH = (#options * optionH) + 4
    
    -- Clamp position to screen bounds
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    if x + optionW + 4 > screenW then
        x = screenW - optionW - 4
    end
    if y + menuH > screenH then
        y = screenH - menuH
    end
    
    -- Draw background
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", x - 2, y - 2, optionW + 4, menuH)
    
    -- Draw border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("line", x - 2, y - 2, optionW + 4, menuH)
    
    -- Store clamped position for click detection
    Dialogs.contextMenu.displayX = x
    Dialogs.contextMenu.displayY = y
    
    -- Draw options
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.normal))
    for i, option in ipairs(options) do
        local optY = y + (i - 1) * optionH
        
        -- Check hover
        local mx, my = love.mouse.getPosition()
        local isHovering = mx >= x and mx <= x + optionW and my >= optY and my <= optY + optionH
        
        if isHovering then
            love.graphics.setColor(Theme.colors.buttonHover)
            love.graphics.rectangle("fill", x, optY, optionW, optionH)
        end
        
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(option, x, optY + 6, optionW, "center")
    end
    
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.title))
end

-- Draw confirmation dialog
function Dialogs.drawConfirmDialog()
    if not Dialogs.confirmDialog then return end
    
    local dialogW, dialogH = 300, 150
    local x = (love.graphics.getWidth() - dialogW) / 2
    local y = (love.graphics.getHeight() - dialogH) / 2
    
    -- Draw overlay
    love.graphics.setColor(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw dialog background
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x - 2, y - 2, dialogW + 4, dialogH + 4)
    
    -- Draw border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("line", x - 2, y - 2, dialogW + 4, dialogH + 4)
    
    -- Draw title
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Delete Item?", x, y + 15, dialogW, "center")
    
    -- Draw message
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.printf("Are you sure you want to delete all of these items?", x + 10, y + 45, dialogW - 20, "center")
    
    -- Draw buttons
    local btnW, btnH = 70, 28
    local btnSpacing = 20
    local totalBtnWidth = (btnW * 2) + btnSpacing
    local startX = x + (dialogW - totalBtnWidth) / 2
    local yesX = startX
    local noX = startX + btnW + btnSpacing
    local btnY = y + dialogH - 45
    
    local mx, my = love.mouse.getPosition()
    
    -- Yes button
    local yesHover = mx >= yesX and mx <= yesX + btnW and my >= btnY and my <= btnY + btnH
    Theme.drawButton(yesX, btnY, btnW, btnH, "Yes", yesHover, Theme.colors.buttonYes, Theme.colors.buttonYesHover)
    
    -- No button
    local noHover = mx >= noX and mx <= noX + btnW and my >= btnY and my <= btnY + btnH
    Theme.drawButton(noX, btnY, btnW, btnH, "No", noHover, Theme.colors.buttonNo, Theme.colors.buttonNoHover)
    
    love.graphics.setFont(love.graphics.newFont(Theme.fonts.title))
    
    -- Store button rects for click detection
    Dialogs.confirmDialog.yesRect = {x = yesX, y = btnY, w = btnW, h = btnH}
    Dialogs.confirmDialog.noRect = {x = noX, y = btnY, w = btnW, h = btnH}
end

-- Handle context menu interactions
function Dialogs.handleContextMenuClick(x, y, button)
    if not Dialogs.contextMenu then return false end
    
    if button == 1 then
        local optionH = 28
        local optionW = 100
        local displayX = Dialogs.contextMenu.displayX or Dialogs.contextMenu.x
        local displayY = Dialogs.contextMenu.displayY or Dialogs.contextMenu.y
        
        -- Check if Delete was clicked
        if x >= displayX and x <= displayX + optionW 
           and y >= displayY and y <= displayY + optionH then
            -- Show confirmation dialog
            Dialogs.confirmDialog = {itemId = Dialogs.contextMenu.itemId, yesRect = nil, noRect = nil}
            Dialogs.contextMenu = nil
            return true
        end
    end
    
    -- Close context menu on click outside
    Dialogs.contextMenu = nil
    return false
end

-- Handle confirmation dialog interactions
function Dialogs.handleConfirmDialogClick(x, y, button)
    if not Dialogs.confirmDialog then return false end
    
    if button == 1 then
        -- Yes button clicked
        if Dialogs.confirmDialog.yesRect and x >= Dialogs.confirmDialog.yesRect.x 
           and x <= Dialogs.confirmDialog.yesRect.x + Dialogs.confirmDialog.yesRect.w 
           and y >= Dialogs.confirmDialog.yesRect.y 
           and y <= Dialogs.confirmDialog.yesRect.y + Dialogs.confirmDialog.yesRect.h then
            
            -- Delete the item
            local cargoEntities = ECS.getEntitiesWith({"InputControlled", "Cargo"})
            if #cargoEntities > 0 then
                local cargo = ECS.getComponent(cargoEntities[1], "Cargo")
                if cargo and cargo.items[Dialogs.confirmDialog.itemId] then
                    cargo.items[Dialogs.confirmDialog.itemId] = nil
                    print("Deleted all " .. Dialogs.confirmDialog.itemId .. " items")
                end
            end
            
            Dialogs.confirmDialog = nil
            Dialogs.contextMenu = nil
            return true
        end
        
        -- No button clicked
        if Dialogs.confirmDialog.noRect and x >= Dialogs.confirmDialog.noRect.x 
           and x <= Dialogs.confirmDialog.noRect.x + Dialogs.confirmDialog.noRect.w 
           and y >= Dialogs.confirmDialog.noRect.y 
           and y <= Dialogs.confirmDialog.noRect.y + Dialogs.confirmDialog.noRect.h then
            Dialogs.confirmDialog = nil
            return true
        end
    end
    
    return false
end

return Dialogs
