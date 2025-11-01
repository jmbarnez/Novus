---@diagnostic disable: undefined-global
-- UI Notifications Module - Displays text notifications for items added to cargo
-- Simple text popups that fade out over time

local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')

local Notifications = {
    notifications = {},  -- {type, text, timer, maxTimer, stackKey, [skillData for XP bars]}
    _slots = {}, -- [{y, targetY, notification, slotActive}], stays stable except for shifting on expire
    slotHeight = 52, -- max slot height (taller of all notif types)
    verticalGap = 6,
    animSpeed = 320,
}

-- Internally build slots if needed
function Notifications._rebuildSlots()
    local slots = {}
    local yStart = love.graphics.getHeight() - Scaling.scaleY(40) - Scaling.scaleSize(52)
    local slotH = Scaling.scaleSize(52) + Scaling.scaleY(Notifications.verticalGap)
    for i, notif in ipairs(Notifications.notifications) do
        slots[i] = {
            y = yStart - (i-1)*slotH,
            targetY = yStart - (i-1)*slotH,
            notif = notif,
            slotActive = true,
        }
    end
    Notifications._slots = slots
end

function Notifications.addLevelNotification(newLevel)
    local text = string.format("Core Level Up -> %d", newLevel)
    Notifications.addNotification {
        type = 'level',
        text = text,
        timer = 4.5,
        stackKey = "player_level"
    }
end

-- Adds a notification: type can be 'item' or 'skill'
function Notifications.addNotification(args)
    -- Args: type, text, timer, stackKey, skillData, itemCount
    assert(args.type)
    assert(args.text)
    local timer = args.timer or 3.5
    local stackKey = args.stackKey -- if set, stack with existing notification of same stackKey
    local skillData = args.skillData -- XP data for skill notifications
    local itemCount = args.itemCount -- Count for item notifications (for accumulation)

    if stackKey then
        for _, notif in ipairs(Notifications.notifications) do
            if notif.stackKey == stackKey and notif.type == args.type then
                -- For items, accumulate counts
                if args.type == 'item' and itemCount then
                    notif.itemCount = (notif.itemCount or 0) + itemCount
                    -- Extract item name from existing text and update with new count
                    local itemName = notif.text:match("Picked up: (.+) x%d+")
                    if itemName then
                        notif.text = ('Picked up: %s x%d'):format(itemName, notif.itemCount)
                    end
                else
                    notif.text = args.text -- Update to new text (for XP updates)
                end
                notif.timer = notif.maxTimer  -- Reset timer
                if skillData then
                    notif.skillData = skillData -- Update skill data
                end
                return
            end
        end
    end
    -- Replace table.insert with direct push to both notifications and slot
    -- But defer slot rebuilding until update/draw (for batch safety)
    -- Insert as normal
    table.insert(Notifications.notifications, {
        type = args.type,
        text = args.text,
        timer = args.timer or 3.5,
        maxTimer = args.timer or 3.5,
        stackKey = args.stackKey,
        skillData = args.skillData,
        itemCount = args.itemCount,
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
            stackKey = stackKey,
            itemCount = count
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
        stackKey = stackKey,
        skillData = skillData
    }
end

function Notifications.update(dt)
    -- Remove expired notifications
    local dirty = false
    local i = 1
    while i <= #Notifications.notifications do
        local notif = Notifications.notifications[i]
        notif.timer = notif.timer - dt
        if notif.timer <= 0 then
            table.remove(Notifications.notifications, i)
            dirty = true
        else
            i = i + 1
        end
    end
    -- Only rebuild slots when things change
    if dirty or #Notifications._slots ~= #Notifications.notifications then
        Notifications._rebuildSlots()
    end
    -- Animate slot y towards their target y for smooth sliding
    local speed = Notifications.animSpeed * dt
    for i, slot in ipairs(Notifications._slots) do
        if slot.y ~= slot.targetY then
            -- Animate y towards targetY
            if math.abs(slot.y - slot.targetY) < speed then
                slot.y = slot.targetY
            else
                slot.y = slot.y + (slot.targetY > slot.y and speed or -speed)
            end
        end
    end

end

-- Draw notifications (bottom-left, one per line, skill-theme style)
function Notifications.draw()
    if #Notifications.notifications == 0 then return end
    local Scaling = require('src.scaling')
    local Theme = require('src.ui.plasma_theme')
    local x = Scaling.scaleX(20)
    local maxNotifWidth = Scaling.scaleSize(400)
    local normalFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    love.graphics.setFont(normalFont)

    for i, slot in ipairs(Notifications._slots) do
        local notif = slot.notif
        local alpha = notif.timer / notif.maxTimer
        local y = slot.y

        -- Calculate height
        local notifHeight = Scaling.scaleSize(36)
        if notif.type == 'skill' and notif.skillData then
            notifHeight = Scaling.scaleSize(52)
        elseif notif.type == 'level' then
            notifHeight = Scaling.scaleSize(44)
        end

        -- Measure text width to fit background
        local textPadding = Scaling.scaleX(14)
        local textWidth = normalFont:getWidth(notif.text)
        local notifWidth = math.min(maxNotifWidth, textWidth + textPadding * 2)

        if notif.type == 'level' then
            local cornerRadius = 0  -- Use sharp corners for plasma theme
            local bgColor = Theme.colors.surfaceAlt or Theme.colors.surface
            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha * 0.95)
            love.graphics.rectangle('fill', x, y, notifWidth, notifHeight, cornerRadius, cornerRadius)
            local accentColor = Theme.colors.textAccent or Theme.palette.accent
            love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', x, y, notifWidth, notifHeight, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
            love.graphics.printf(notif.text, x + Scaling.scaleX(16), y + Scaling.scaleY(12), notifWidth - Scaling.scaleX(32), "left")

            local barX = x + Scaling.scaleX(16)
            local barWidth = notifWidth - Scaling.scaleX(32)
            local barHeight = Scaling.scaleSize(4)
            local barY = y + notifHeight - Scaling.scaleY(14)
            local barBg = Theme.colors.surface or Theme.colors.surfaceAlt
            love.graphics.setColor(barBg[1], barBg[2], barBg[3], alpha * 0.6)
            love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)
            love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], alpha * 0.9)
            love.graphics.rectangle('fill', barX, barY, barWidth, math.max(1, barHeight * 0.45))
        else
            local cornerRadius = 0  -- Use sharp corners for plasma theme
            love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], alpha * 0.92)
            love.graphics.rectangle('fill', x, y, notifWidth, notifHeight, cornerRadius, cornerRadius)
            love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle('line', x, y, notifWidth, notifHeight, cornerRadius, cornerRadius)

            if notif.type == 'skill' and notif.text:find('LVL UP!') then
                local successColor = Theme.colors.success or {0.1, 1.0, 0.2, 1}
                love.graphics.setColor(successColor[1], successColor[2], successColor[3], alpha)
            else
                love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
            end
            love.graphics.print(notif.text, x + textPadding, y + Scaling.scaleY(7))

            if notif.type == 'skill' and notif.skillData then
                local barX = x + textPadding
                local barY = y + Scaling.scaleY(28)
                local barWidth = notifWidth - textPadding * 2
                local barHeight = Scaling.scaleSize(8)
                love.graphics.setColor(Theme.colors.surfaceAlt[1], Theme.colors.surfaceAlt[2], Theme.colors.surfaceAlt[3], alpha)
                love.graphics.rectangle('fill', barX, barY, barWidth, barHeight)
                love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2], Theme.colors.borderAlt[3], alpha)
                love.graphics.rectangle('line', barX, barY, barWidth, barHeight)
                local accentColor = Theme.colors.textAccent or Theme.palette.accent
                local barColor = {accentColor[1], accentColor[2], accentColor[3]}
                if notif.text:find('SALVAGING') then 
                    local successColor = Theme.colors.success or {0.1, 1.0, 0.2, 1}
                    barColor = {successColor[1], successColor[2], successColor[3]}
                end
                local xpRatio = math.min(1, notif.skillData.experience / notif.skillData.requiredXp)
                local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
                love.graphics.setColor(barColor[1], barColor[2], barColor[3], alpha)
                love.graphics.rectangle('fill', barX + 1, barY + 1, fillWidth, barHeight - 2)
            end
        end
    end
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

return Notifications
