---@diagnostic disable: undefined-global
local Theme = require('src.ui.plasma_theme')

local Dialogs = {}
Dialogs.confirmDialog = false
Dialogs.confirmCallback = nil

function Dialogs.showConfirm(message, onResult)
    Dialogs.confirmDialog = true
    Dialogs.confirmMessage = message or "Are you sure?"
    Dialogs.confirmCallback = onResult
end

function Dialogs.hideConfirm()
    Dialogs.confirmDialog = false
    Dialogs.confirmMessage = nil
    Dialogs.confirmCallback = nil
end

function Dialogs.drawConfirmDialog()
    if not Dialogs.confirmDialog then return end
    local lg = love.graphics
    local sw, sh = lg.getWidth(), lg.getHeight()
    local font = Theme.getFontBold(16)
    lg.setFont(font)
    local padding = Theme.spacing.sm * 2

    local txt = Dialogs.confirmMessage or "Are you sure?"
    local txtW = font:getWidth(txt)
    local btnW, btnH = 140, 32
    local boxW = math.max(txtW + padding * 2, btnW * 2 + padding * 3)
    local boxH = btnH * 1 + padding * 3 + 24
    local boxX = (sw - boxW) / 2
    local boxY = (sh - boxH) / 2

    -- Overlay
    lg.setColor(table.unpack(Theme.colors.overlay))
    lg.rectangle('fill', 0, 0, sw, sh)
    Theme.draw3DBorder(boxX, boxY, boxW, boxH, Theme.window.borderThickness)

    -- Message
    local msgX = boxX + padding
    local msgY = boxY + padding
    lg.setColor(table.unpack(Theme.colors.text))
    lg.print(txt, msgX, msgY)

    -- Buttons
    local btnY = boxY + boxH - padding - btnH
    local yesBtn = { x = boxX + padding, y = btnY, w = btnW, h = btnH }
    local noBtn = { x = boxX + boxW - padding - btnW, y = btnY, w = btnW, h = btnH }
    Dialogs._yesBtn = yesBtn
    Dialogs._noBtn = noBtn

    local mx, my = love.mouse.getPosition()
    local yesHover = mx >= yesBtn.x and mx <= yesBtn.x + yesBtn.w and my >= yesBtn.y and my <= yesBtn.y + yesBtn.h
    local noHover = mx >= noBtn.x and mx <= noBtn.x + noBtn.w and my >= noBtn.y and my <= noBtn.y + noBtn.h

    Theme.drawButton(yesBtn.x, yesBtn.y, yesBtn.w, yesBtn.h, "Yes", yesHover, Theme.colors.success, Theme.colors.successHover)
    Theme.drawButton(noBtn.x, noBtn.y, noBtn.w, noBtn.h, "No", noHover, Theme.colors.danger, Theme.colors.dangerHover)
end

function Dialogs.mousepressed(x, y, button)
    if not Dialogs.confirmDialog or button ~= 1 then return end
    local b = Dialogs._yesBtn
    if b and x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then
        if Dialogs.confirmCallback then Dialogs.confirmCallback(true) end
        Dialogs.hideConfirm()
        return true
    end
    b = Dialogs._noBtn
    if b and x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then
        if Dialogs.confirmCallback then Dialogs.confirmCallback(false) end
        Dialogs.hideConfirm()
        return true
    end
    return false
end

return Dialogs


