local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"
local SoundManager = require "src.managers.sound_manager"
local SaveManager = require "src.managers.save_manager"
local SettingsPanel = require "src.ui.settings_panel"

local PauseMenu = {}

local buttons = {
    { label = "RESUME", action = "resume" },
    { label = "SAVE GAME", action = "save" },
    { label = "SETTINGS", action = "settings" },
    { label = "MAIN MENU", action = "menu" },
}

local settingsOpen = false
local saveOpen = false
local saveRects = {}

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function getLayout()
    local sw, sh = love.graphics.getDimensions()
    local spacing = Theme.spacing
    local buttonWidth = spacing.buttonWidth
    local buttonHeight = spacing.buttonHeight
    local buttonSpacing = spacing.buttonSpacing

    local totalHeight = #buttons * buttonHeight + (#buttons - 1) * buttonSpacing
    local boxWidth = buttonWidth + 80
    local boxHeight = totalHeight + 120

    local boxX = (sw - boxWidth) * 0.5
    local boxY = (sh - boxHeight) * 0.5

    local startX = boxX + (boxWidth - buttonWidth) * 0.5
    local startY = boxY + 80

    local rects = {}
    for i = 1, #buttons do
        local y = startY + (i - 1) * (buttonHeight + buttonSpacing)
        rects[i] = {
            x = startX,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        }
    end

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        buttonRects = rects,
    }
end

local function getSaveWindowRect()
    local sw, sh = love.graphics.getDimensions()
    local width = math.min(420, sw * 0.6)
    local height = 260

    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

local function drawSaveWindow()
    if not saveOpen then
        return
    end

    local wx, wy, ww, wh = getSaveWindowRect()
    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Save Game",
        bottomText = nil,
        showClose = true,
    })

    saveRects.close = layout.close

    local content = layout.content
    local font = Theme.getFont("button")
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.textPrimary)

    local buttonWidth = math.min(content.w - 40, 260)
    local buttonHeight = Theme.spacing.buttonHeight or 42
    local buttonSpacing = 12
    local startX = content.x + (content.w - buttonWidth) * 0.5
    local startY = content.y + 10

    saveRects.slots = saveRects.slots or {}

    for slot = 1, 3 do
        local rectY = startY + (slot - 1) * (buttonHeight + buttonSpacing)
        local rect = {
            x = startX,
            y = rectY,
            w = buttonWidth,
            h = buttonHeight,
        }
        saveRects.slots[slot] = rect

        local hasSave = SaveManager.has_save(slot)
        local label
        if hasSave then
            label = string.format("Slot %d - Overwrite", slot)
        else
            label = string.format("Slot %d - Empty", slot)
        end

        local mx, my = love.mouse.getPosition()
        local hovered = mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h
        local state = hovered and "hover" or "default"
        Theme.drawButton(rect.x, rect.y, rect.w, rect.h, label, state, font)
    end
end

function PauseMenu.update(dt)
    if settingsOpen and SettingsPanel and SettingsPanel.update then
        SettingsPanel.update(dt)
    end
end

function PauseMenu.draw()
    local sw, sh = love.graphics.getDimensions()
    local dim = Theme.colors.overlay.screenDim
    love.graphics.setColor(dim[1], dim[2], dim[3], dim[4] or 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local layout = getLayout()
    local boxX = layout.boxX
    local boxY = layout.boxY
    local boxWidth = layout.boxWidth
    local boxHeight = layout.boxHeight
    local buttonRects = layout.buttonRects

    local bgColor = Theme.getBackgroundColor()
    local buttonColors = Theme.colors.button
    local textPrimary = Theme.colors.textPrimary

    local rounding = Theme.shapes.buttonRounding or 0
    local outlineWidth = Theme.shapes.outlineWidth or 1.5

    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, rounding, rounding)
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.setColor(buttonColors.outline)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, rounding, rounding)

    local titleFont = Theme.getFont("button")
    love.graphics.setFont(titleFont)
    local titleText = "PAUSED"
    love.graphics.setColor(textPrimary)
    love.graphics.printf(titleText, boxX, boxY + 26, boxWidth, "center")

    local mx, my = love.mouse.getPosition()
    local buttonFont = Theme.getFont("button")
    love.graphics.setFont(buttonFont)

    local hoveredIndex
    for i, button in ipairs(buttons) do
        local rect = buttonRects[i]
        local hovered = (not settingsOpen) and pointInRect(mx, my, rect)

        local state = hovered and "hover" or "default"
        Theme.drawButton(rect.x, rect.y, rect.w, rect.h, button.label, state, buttonFont)

        if hovered then
            hoveredIndex = i
        end
    end

    local prevHovered = PauseMenu._hoveredIndex
    if settingsOpen or saveOpen then
        hoveredIndex = nil
        PauseMenu._hoveredIndex = nil
    else
        PauseMenu._hoveredIndex = hoveredIndex
        if hoveredIndex and hoveredIndex ~= prevHovered then
            SoundManager.play_sound("button_hover")
        end
    end

    if settingsOpen and SettingsPanel and SettingsPanel.draw then
        SettingsPanel.draw()
    end
    drawSaveWindow()

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu.mousepressed(x, y, button)
    if button ~= 1 then
        return nil
    end

    if saveOpen then
        local closeRect = saveRects.close
        if closeRect and pointInRect(x, y, closeRect) then
            saveOpen = false
            return nil
        end

        if saveRects.slots then
            for slot = 1, 3 do
                local rect = saveRects.slots[slot]
                if rect and pointInRect(x, y, rect) then
                    saveOpen = false
                    return string.format("save_slot_%d", slot)
                end
            end
        end

        return nil
    end

    if settingsOpen and SettingsPanel and SettingsPanel.mousepressed then
        local result = SettingsPanel.mousepressed(x, y, button)
        if result == "close" then
            settingsOpen = false
            if SettingsPanel.reset then
                SettingsPanel.reset()
            end
            return nil
        end
        if result then
            return nil
        end
        return nil
    end

    local layout = getLayout()
    local buttonRects = layout.buttonRects

    for i, rect in ipairs(buttonRects) do
        if pointInRect(x, y, rect) then
            local data = buttons[i]
            if data and data.action == "save" then
                saveOpen = true
                return nil
            end
            if data and data.action == "settings" then
                settingsOpen = true
                if SettingsPanel and SettingsPanel.reset then
                    SettingsPanel.reset()
                end
                return nil
            end
            if data and data.action then
                settingsOpen = false
                return data.action
            end
            return nil
        end
    end

    return nil
end

function PauseMenu.reset()
    settingsOpen = false
    saveOpen = false
    if SettingsPanel and SettingsPanel.reset then
        SettingsPanel.reset()
    end
end

return PauseMenu
