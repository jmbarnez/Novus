---@diagnostic disable: undefined-global
-- UI Skill Notifications Module - Displays popup notifications for experience gains
-- Shows skill name, XP gained, and the updated experience bar

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local SkillNotifications = {
    notifications = {},  -- {skillName, xpGain, level, experience, requiredXp, timer, maxTimer}
}

-- Add a skill experience notification
function SkillNotifications.addNotification(skillName, xpGain, skillData)
    -- Check if we already have a notification for this skill
    for _, notif in ipairs(SkillNotifications.notifications) do
        if notif.skillName == skillName then
            -- Stack: increase XP gain and reset timer
            notif.xpGain = notif.xpGain + xpGain
            notif.timer = notif.maxTimer
            notif.level = skillData.level
            notif.experience = skillData.experience
            notif.requiredXp = skillData.requiredXp
            notif.leveledUp = (skillData.levelUp == true) or notif.leveledUp
            return
        end
    end
    
    -- Create new notification for this skill
    table.insert(SkillNotifications.notifications, {
        skillName = skillName,
        xpGain = xpGain,
        level = skillData.level,
        experience = skillData.experience,
        requiredXp = skillData.requiredXp,
        leveledUp = skillData.levelUp == true,
        timer = 4.0,  -- Display for 4 seconds
        maxTimer = 4.0,
    })
end

-- Update notifications (fade out)
function SkillNotifications.update(dt)
    local i = 1
    while i <= #SkillNotifications.notifications do
        local notif = SkillNotifications.notifications[i]
        notif.timer = notif.timer - dt
        
        if notif.timer <= 0 then
            table.remove(SkillNotifications.notifications, i)
        else
            i = i + 1
        end
    end
end

-- Draw all skill notifications
function SkillNotifications.draw()
    if #SkillNotifications.notifications == 0 then
        return
    end
    
    local screenW = love.graphics.getWidth()
    local notifWidth = Scaling.scaleSize(220)
    local notifHeight = Scaling.scaleSize(44)
    local y = Scaling.scaleY(18)
    local x = (screenW - notifWidth) / 2
    
    -- Set fonts once
    local normalFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    local smallFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.small))
    
    for _, notif in ipairs(SkillNotifications.notifications) do
        local alpha = notif.timer / notif.maxTimer
        -- Background
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.92)
        love.graphics.rectangle("fill", x, y, notifWidth, notifHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
        -- Border
        love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, notifWidth, notifHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
        -- Skill name and XP
        love.graphics.setFont(normalFont)
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        local skillLabel = string.upper(notif.skillName)
        if notif.leveledUp then
            skillLabel = skillLabel .. " ↑ LVL UP!"
            love.graphics.setColor(0.2, 1, 0.2, alpha)
        end
        love.graphics.print(skillLabel, x + Scaling.scaleX(12), y + Scaling.scaleY(6))
        love.graphics.setFont(smallFont)
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        love.graphics.print("+" .. notif.xpGain .. " XP", x + notifWidth - Scaling.scaleX(70), y + Scaling.scaleY(6))
        -- Experience bar
        local barX = x + Scaling.scaleX(12)
        local barY = y + notifHeight - Scaling.scaleY(16)
        local barWidth = notifWidth - Scaling.scaleX(24)
        local barHeight = Scaling.scaleSize(8)
        love.graphics.setColor(0.1, 0.1, 0.1, alpha)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, Scaling.scaleSize(4), Scaling.scaleSize(4))
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, Scaling.scaleSize(4), Scaling.scaleSize(4))
        local xpRatio = notif.experience / notif.requiredXp
        local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
        love.graphics.setColor(0.2, 0.6, 1.0, alpha)
        love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2, Scaling.scaleSize(3), Scaling.scaleSize(3))
        -- XP text (removed from inside the bar)
        y = y + notifHeight + Scaling.scaleY(8)
    end
    
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

return SkillNotifications
