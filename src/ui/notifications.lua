---@diagnostic disable: undefined-global
-- UI Notifications Module - Displays text notifications for items added to cargo
-- Simple text popups that fade out over time

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Notifications = {
    notifications = {},  -- {text, timer, maxTimer}
}

-- Add a text notification
function Notifications.addNotification(itemId, count, playerX, playerY)
    count = count or 1
    
    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    
    if itemDef then
        -- Check if we already have a notification for this item
        for _, notif in ipairs(Notifications.notifications) do
            if notif.itemId == itemId then
                -- Stack: increase count and reset timer
                notif.count = notif.count + count
                notif.timer = notif.maxTimer
                return
            end
        end
        
        -- Create new notification for this item type
        table.insert(Notifications.notifications, {
            itemId = itemId,
            count = count,
            timer = 3.0,  -- Display for 3 seconds
            maxTimer = 3.0,
        })
    end
end

-- Update notifications (fade out)
function Notifications.update(dt)
    local i = 1
    while i <= #Notifications.notifications do
        local notif = Notifications.notifications[i]
        notif.timer = notif.timer - dt
        
        if notif.timer <= 0 then
            table.remove(Notifications.notifications, i)
        else
            i = i + 1
        end
    end
end

-- Draw all notifications
function Notifications.draw(cameraX, cameraY, cameraZoom)
    if #Notifications.notifications == 0 then
        return
    end
    
    local ItemDefs = require('src.items.item_loader')
    
    local x = Scaling.scaleX(20)
    local y = love.graphics.getHeight() - Scaling.scaleY(40)  -- Bottom left
    local lineHeight = Scaling.scaleSize(25)
    
    local font = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    love.graphics.setFont(font)
    
    for _, notif in ipairs(Notifications.notifications) do
        -- Calculate alpha fade (starts at 1, ends at 0)
        local alpha = notif.timer / notif.maxTimer
        
        -- Get item definition
        local itemDef = ItemDefs[notif.itemId]
        if itemDef then
            local text = "Picked up: " .. itemDef.name .. " x" .. notif.count
            
            -- Draw text with fade
            love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
            love.graphics.print(text, x, y)
            
            y = y - lineHeight  -- Stack upwards from bottom
        end
    end
    
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

return Notifications
