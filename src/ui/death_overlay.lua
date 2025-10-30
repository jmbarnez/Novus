---@diagnostic disable: undefined-global
local Theme = require('src.ui.plasma_theme')
local DeathOverlay = {}

DeathOverlay.isVisible = false
DeathOverlay.onRespawn = nil
DeathOverlay.onRageQuit = nil
local hoverState = { respawn = false, quit = false }

-- Dialogs implementation moved to a separate module
local Dialogs = require('src.ui.dialogs')

function DeathOverlay.show(onRespawn, onRageQuit)
    DeathOverlay.isVisible = true
    DeathOverlay.onRespawn = onRespawn
    DeathOverlay.onRageQuit = onRageQuit
end

function DeathOverlay.hide()
    DeathOverlay.isVisible = false
end

local function centerBox(w, h)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    return (sw - w) / 2, (sh - h) / 2
end

function DeathOverlay.draw()
    if not DeathOverlay.isVisible then return end
    local lg = love.graphics
    local sw, sh = lg.getWidth(), lg.getHeight()
    local buttonFontSize = 16
    local buttonFont = Theme.getFontBold(buttonFontSize)
    lg.setFont(buttonFont)
    local padding = Theme.spacing.sm * 2

    local btnW = 290
    local btnH = buttonFontSize + padding * 2
    local gap = 16
    local boxW = btnW + padding * 2
    local boxH = btnH * 2 + gap + padding * 2
    local boxX, boxY = centerBox(boxW, boxH)

    -- Overlay
    lg.setColor(table.unpack(Theme.colors.overlay))
    lg.rectangle('fill', 0, 0, sw, sh)
    Theme.draw3DBorder(boxX, boxY, boxW, boxH, Theme.window.borderThickness)

    -- Center buttons
    local firstBtnY = boxY + padding
    local respawnBtn = {
        x = boxX + padding,
        y = firstBtnY,
        w = btnW,
        h = btnH
    }
    local quitBtn = {
        x = boxX + padding,
        y = firstBtnY + btnH + gap,
        w = btnW,
        h = btnH
    }
    DeathOverlay._respawnBtn = respawnBtn
    DeathOverlay._quitBtn = quitBtn

    local mx, my = love.mouse.getPosition()
    hoverState.respawn = mx >= respawnBtn.x and mx <= respawnBtn.x + respawnBtn.w and my >= respawnBtn.y and my <= respawnBtn.y + respawnBtn.h
    hoverState.quit = mx >= quitBtn.x and mx <= quitBtn.x + quitBtn.w and my >= quitBtn.y and my <= quitBtn.y + quitBtn.h

    Theme.drawButton(
        respawnBtn.x, respawnBtn.y, respawnBtn.w, respawnBtn.h,
        "Respawn (Random Point)",
        hoverState.respawn,
        Theme.colors.success,
        Theme.colors.successHover)

    Theme.drawButton(
        quitBtn.x, quitBtn.y, quitBtn.w, quitBtn.h,
        "Rage Quit (Main Menu)",
        hoverState.quit,
        Theme.colors.danger,
        Theme.colors.dangerHover)
end

function DeathOverlay.mousepressed(x, y, button)
    if not DeathOverlay.isVisible or button ~= 1 then return end
    local b = DeathOverlay._respawnBtn
    if b and x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then
        if DeathOverlay.onRespawn then DeathOverlay.onRespawn() end
        DeathOverlay.hide()
        return
    end
    b = DeathOverlay._quitBtn
    if b and x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then
        if DeathOverlay.onRageQuit then DeathOverlay.onRageQuit() end
        DeathOverlay.hide()
        return
    end
end

return DeathOverlay
