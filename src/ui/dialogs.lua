---@diagnostic disable: undefined-global
-- UI Dialogs Module - Handles context menus and confirmation dialogs with theme support
-- Modular dialog system for user confirmations

local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local Scaling = require('src.scaling')

local Dialogs = {
    contextMenu = nil,      -- {itemId, x, y}
    confirmDialog = nil,    -- {itemId, yesRect, noRect}
}

-- Draw context menu
function Dialogs.drawContextMenu(x, y)
    if not Dialogs.contextMenu then return end

    local options = {"Delete"}
    local optionH_ui = 28
    local optionW_ui = 100
    local optionH = Scaling.scaleSize(optionH_ui)
    local optionW = Scaling.scaleSize(optionW_ui)
    local menuH = (#options * optionH) + Scaling.scaleSize(4)

    -- Convert menu origin to screen space and clamp to screen bounds
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local sX, sY = Scaling.toScreenCanvas(x, y)
    if sX + optionW + Scaling.scaleSize(4) > screenW then
        sX = screenW - optionW - Scaling.scaleSize(4)
        x, y = Scaling.toUI(sX, sY)
    end
    if sY + menuH > screenH then
        sY = screenH - menuH
        x, y = Scaling.toUI(sX, sY)
    end

    -- Store clamped UI position for click detection
    local cm = Dialogs.contextMenu
    if cm then
        cm.displayX = x
        cm.displayY = y
    end

    -- Draw options
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.normal)))
    for i, option in ipairs(options) do
        local optY_ui = y + (i - 1) * optionH_ui
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
        local isHovering = mx >= x and mx <= x + optionW_ui and my >= optY_ui and my <= optY_ui + optionH_ui

        -- Convert menu origin (UI space) to screen space for drawing
        local screenX, screenY = Scaling.toScreenCanvas(x, optY_ui)
        if isHovering then
            love.graphics.setColor(Theme.colors.buttonHover)
            love.graphics.rectangle("fill", screenX, screenY, optionW, optionH)
        end

        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(option, screenX, screenY + Scaling.scaleY(6), optionW, "center")
    end
    
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

-- Draw confirmation dialog
function Dialogs.drawConfirmDialog()
    if not Dialogs.confirmDialog then return end
    
    local dialogW, dialogH = Scaling.scaleSize(300), Scaling.scaleSize(150)
    local x = (love.graphics.getWidth() - dialogW) / 2
    local y = (love.graphics.getHeight() - dialogH) / 2
    
    -- Draw overlay
    love.graphics.setColor(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw dialog background
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x - Scaling.scaleSize(2), y - Scaling.scaleSize(2), dialogW + Scaling.scaleSize(4), dialogH + Scaling.scaleSize(4))
    
    -- Draw border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("line", x - Scaling.scaleSize(2), y - Scaling.scaleSize(2), dialogW + Scaling.scaleSize(4), dialogH + Scaling.scaleSize(4))
    
    -- Draw title
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Delete Item?", x, y + Scaling.scaleY(15), dialogW, "center")
    
    -- Draw message
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.small)))
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.printf("Are you sure you want to delete all of these items?", x + Scaling.scaleX(10), y + Scaling.scaleY(45), dialogW - Scaling.scaleX(20), "center")
    
    -- Draw buttons
    local btnW, btnH = Scaling.scaleSize(70), Scaling.scaleSize(28)
    local btnSpacing = Scaling.scaleSize(20)
    local totalBtnWidth = (btnW * 2) + btnSpacing
    local startX = x + (dialogW - totalBtnWidth) / 2
    local yesX = startX
    local noX = startX + btnW + btnSpacing
    local btnY = y + dialogH - Scaling.scaleY(45)
    
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    -- Convert button boxes to UI space for hover checks
    local uiYesX, uiYesY = Scaling.toUI(yesX, btnY)
    local uiNoX, uiNoY = Scaling.toUI(noX, btnY)
    local uiBtnW, uiBtnH = btnW / Scaling.getScale(), btnH / Scaling.getScale()

    -- Yes button
    local yesHover = mx >= uiYesX and mx <= uiYesX + uiBtnW and my >= uiYesY and my <= uiYesY + uiBtnH
    Theme.drawButton(yesX, btnY, btnW, btnH, "Yes", yesHover, Theme.colors.buttonYes, Theme.colors.buttonYesHover)
    
    -- No button
    local noHover = mx >= uiNoX and mx <= uiNoX + uiBtnW and my >= uiNoY and my <= uiNoY + uiBtnH
    Theme.drawButton(noX, btnY, btnW, btnH, "No", noHover, Theme.colors.buttonNo, Theme.colors.buttonNoHover)
    
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
    
    -- Store button rects for click detection
    -- Store button rects in UI/reference space
    Dialogs.confirmDialog.yesRect = {x = uiYesX, y = uiYesY, w = uiBtnW, h = uiBtnH}
    Dialogs.confirmDialog.noRect = {x = uiNoX, y = uiNoY, w = uiBtnW, h = uiBtnH}
end

-- Handle context menu interactions
function Dialogs.handleContextMenuClick(x, y, button)
    if not Dialogs.contextMenu then return false end
    
    if button == 1 then
        -- Use UI units for options
        local optionH_ui = 28
        local optionW_ui = 100
        local context = Dialogs.contextMenu
        if not context then return false end
        local displayX = context.displayX or context['x'] or 0
        local displayY = context.displayY or context['y'] or 0

        -- Check if Delete was clicked (all in UI space)
        if x >= displayX and x <= displayX + optionW_ui
           and y >= displayY and y <= displayY + optionH_ui then
            -- Show confirmation dialog
            Dialogs.confirmDialog = {itemId = context['itemId'], yesRect = nil, noRect = nil}
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
            local cargoEntities = ECS.getEntitiesWith({"Player", "Cargo"})
            if #cargoEntities > 0 then
                local cargo = ECS.getComponent(cargoEntities[1], "Cargo")
                if cargo then
                    cargo:removeItem(Dialogs.confirmDialog.itemId, 1)
                    -- ...existing code...
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
