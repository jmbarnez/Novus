---@diagnostic disable: undefined-global
-- UI Notifications Module - Displays text notifications for items added to cargo
-- Simple text popups that fade out over time

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Notifications = {
    notifications = {},  -- {type, text, timer, maxTimer, [extra data for stacking]}
}

-- Adds a notification: type can be 'item' or 'skill'
function Notifications.addNotification(args)
    -- Args: type, text, timer, stackKey
    assert(args.type)
    assert(args.text)
    local timer = args.timer or 3.5
    local stackKey = args.stackKey -- if set, stack with existing notification of same stackKey

    if stackKey then
        for _, notif in ipairs(Notifications.notifications) do
            if notif.stackKey == stackKey and notif.type == args.type then
                notif.text = args.text -- Update to new text (for count/xp stack)
                notif.timer = notif.maxTimer  -- Reset timer
                return
            end
        end
    end
    table.insert(Notifications.notifications, {
        type = args.type,
        text = args.text,
        timer = timer,
        maxTimer = timer,
        stackKey = stackKey,
    })
end

-- Helper for item pickups
function Notifications.addItemNotification(itemId, count)
    count = count or 1
    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if itemDef then
        local stackKey = 'item_' .. tostring(itemId)
        Notifications.addNotification {
            type = 'item',
            text = ('Picked up: %s x%d'):format(itemDef.name, count),
            timer = 3.0,
            stackKey = stackKey
        }
    end
end

-- Helper for skill XP gain
function Notifications.addSkillNotification(skillName, xpGain, skillData)
    local stackKey = 'skill_' .. tostring(skillName)
    local text = string.format(
        "%s +%d XP%s",
        string.upper(skillName),
        xpGain,
        (skillData and skillData.levelUp) and "  ↑ LVL UP!" or ""
    )
    Notifications.addNotification {
        type = 'skill',
        text = text,
        timer = 4.0,
        stackKey = stackKey
    }
end

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

-- Draw notifications (bottom-left, one per line, skill-theme style)
function Notifications.draw()
    if #Notifications.notifications == 0 then return end
    local Scaling = require('src.scaling')
    local Theme = require('src.ui.theme')
    local x = Scaling.scaleX(20)
    local y = love.graphics.getHeight() - Scaling.scaleY(40)
    local lineHeight = Scaling.scaleSize(44)
    local notifWidth = Scaling.scaleSize(400)
    local notifHeight = Scaling.scaleSize(36)
    local normalFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    love.graphics.setFont(normalFont)
    for _, notif in ipairs(Notifications.notifications) do
        local alpha = notif.timer / notif.maxTimer
        -- BG
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.92)
        love.graphics.rectangle("fill", x, y, notifWidth, notifHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
        -- Border
        love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, notifWidth, notifHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
        -- Text (XP gain = green if level up, normal for others)
        if notif.type == 'skill' and notif.text:find('LVL UP!') then
            love.graphics.setColor(0.2, 1, 0.2, alpha)
        else
            love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        end
        love.graphics.print(notif.text, x + Scaling.scaleX(14), y + Scaling.scaleY(7))
        y = y - notifHeight - Scaling.scaleY(6)
    end
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

return Notifications
