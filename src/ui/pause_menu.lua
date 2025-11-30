local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"
local SoundManager = require "src.managers.sound_manager"
local SaveManager = require "src.managers.save_manager"
local Config = require "src.config"

local PauseMenu = {}

local buttons = {
    { label = "RESUME", action = "resume" },
    { label = "SAVE GAME", action = "save" },
    { label = "SETTINGS", action = "settings" },
    { label = "MAIN MENU", action = "menu" },
}

local settingsOpen = false
local settingsState
local settingsRects = {}
local settingsActiveSlider
local settingsWindow
local settingsDragActive
local settingsDragOffsetX
local settingsDragOffsetY
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

local function ensureSettingsState()
    if settingsState then
        return
    end

    local master = 1
    if love and love.audio and love.audio.getVolume then
        master = love.audio.getVolume()
    end

    local music = 1
    if SoundManager and SoundManager.get_music_volume then
        music = SoundManager.get_music_volume() or music
    end

    local sfx = 1
    if SoundManager and SoundManager.get_sfx_volume then
        sfx = SoundManager.get_sfx_volume() or sfx
    end

    local nebulaEnabled = true
    if Config and Config.BACKGROUND then
        nebulaEnabled = Config.BACKGROUND.ENABLE_NEBULA ~= false
    end

    if master < 0 then master = 0 end
    if master > 1 then master = 1 end
    if music < 0 then music = 0 end
    if music > 1 then music = 1 end
    if sfx < 0 then sfx = 0 end
    if sfx > 1 then sfx = 1 end

    settingsState = {
        masterVolume = master,
        musicVolume = music,
        sfxVolume = sfx,
        nebulaEnabled = nebulaEnabled,
    }
end

local function getSettingsWindowRect()
    local sw, sh = love.graphics.getDimensions()
    local width = math.min(420, sw * 0.6)
    local height = 320
    
    if settingsWindow then
        local x = settingsWindow.x or (sw - width) * 0.5
        local y = settingsWindow.y or (sh - height) * 0.5
        settingsWindow.width = width
        settingsWindow.height = height
        return x, y, width, height
    end

    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

local function getSaveWindowRect()
    local sw, sh = love.graphics.getDimensions()
    local width = math.min(420, sw * 0.6)
    local height = 260

    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

local function drawSlider(rect, value)
    local c = Theme.colors.cargo
    local shapes = Theme.shapes
    local r = shapes.slotCornerRadius or 2

    love.graphics.setColor(c.barBackground)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, r, r)

    local v = value or 0
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end

    if v > 0 then
        love.graphics.setColor(c.barFill)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w * v, rect.h, r, r)
    end

    love.graphics.setColor(c.barOutline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, r, r)
end

local function drawSliderWithValue(rect, value)
    drawSlider(rect, value)

    local v = value or 0
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end

    local percent = math.floor(v * 100 + 0.5)
    local label = tostring(percent) .. "%"

    local font = Theme.getFont("chat")
    love.graphics.setFont(font)
    local tw = font:getWidth(label)
    local th = font:getHeight()
    local tx = rect.x + rect.w - tw - 4
    local ty = rect.y + (rect.h - th) * 0.5

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(label, tx, ty)
end

local function applySliderValue(kind, t)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end

    ensureSettingsState()

    if kind == "master" then
        settingsState.masterVolume = t
        if SoundManager and SoundManager.set_global_volume then
            SoundManager.set_global_volume(t)
        end
    elseif kind == "music" then
        settingsState.musicVolume = t
        if SoundManager and SoundManager.set_music_volume then
            SoundManager.set_music_volume(t)
        end
    elseif kind == "sfx" then
        settingsState.sfxVolume = t
        if SoundManager and SoundManager.set_sfx_volume then
            SoundManager.set_sfx_volume(t)
        end
    end
end

local function handleSliderClick(x, y, rect, kind)
    if not rect or not pointInRect(x, y, rect) then
        return false
    end

    local px = x
    if px < rect.x then px = rect.x end
    if px > rect.x + rect.w then px = rect.x + rect.w end

    local t = (px - rect.x) / rect.w
    applySliderValue(kind, t)
    settingsActiveSlider = kind
    return true
end

local function drawSettings()
    if not settingsOpen then
        return
    end

    ensureSettingsState()

    local wx, wy, ww, wh = getSettingsWindowRect()
    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Settings",
        bottomText = nil,
        showClose = true,
    })

    settingsRects.close = layout.close
    settingsRects.titleBar = layout.titleBar

    local content = layout.content
    local font = Theme.getFont("chat")
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.textPrimary)

    local sliderWidth = math.min(content.w - 40, 260)
    local sliderHeight = 18
    local sliderX = content.x + 20

    local labelY = content.y + 4
    love.graphics.print("Master Volume", sliderX, labelY)
    local masterRectY = labelY + font:getHeight() + 6

    local masterRect = {
        x = sliderX,
        y = masterRectY,
        w = sliderWidth,
        h = sliderHeight,
    }
    settingsRects.masterSlider = masterRect
    drawSliderWithValue(masterRect, settingsState.masterVolume)

    local musicLabelY = masterRectY + sliderHeight + 28
    love.graphics.print("Music Volume", sliderX, musicLabelY)
    local musicRectY = musicLabelY + font:getHeight() + 6

    local musicRect = {
        x = sliderX,
        y = musicRectY,
        w = sliderWidth,
        h = sliderHeight,
    }
    settingsRects.musicSlider = musicRect
    drawSliderWithValue(musicRect, settingsState.musicVolume)

    local sfxLabelY = musicRectY + sliderHeight + 28
    love.graphics.print("SFX Volume", sliderX, sfxLabelY)
    local sfxRectY = sfxLabelY + font:getHeight() + 6

    local sfxRect = {
        x = sliderX,
        y = sfxRectY,
        w = sliderWidth,
        h = sliderHeight,
    }
    settingsRects.sfxSlider = sfxRect
    drawSliderWithValue(sfxRect, settingsState.sfxVolume)

    local graphicsLabelY = sfxRectY + sliderHeight + 30
    love.graphics.print("Graphics", sliderX, graphicsLabelY)
    local toggleY = graphicsLabelY + font:getHeight() + 6

    local toggleWidth = math.min(sliderWidth, 200)
    local toggleHeight = sliderHeight
    local nebulaRect = {
        x = sliderX,
        y = toggleY,
        w = toggleWidth,
        h = toggleHeight,
    }
    settingsRects.nebulaToggle = nebulaRect

    local enabled = settingsState.nebulaEnabled
    local label = enabled and "Nebula: ON" or "Nebula: OFF"
    local state = enabled and "active" or "default"
    Theme.drawButton(nebulaRect.x, nebulaRect.y, nebulaRect.w, nebulaRect.h, label, state, font)
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
    if not settingsOpen then
        settingsActiveSlider = nil
        settingsDragActive = nil
        return
    end

    if not love.mouse.isDown(1) then
        settingsActiveSlider = nil
        settingsDragActive = nil
        return
    end

    if settingsDragActive then
        local mx, my = love.mouse.getPosition()
        local sw, sh = love.graphics.getDimensions()
        local _, _, ww, wh = getSettingsWindowRect()

        local new_x = mx - (settingsDragOffsetX or 0)
        local new_y = my - (settingsDragOffsetY or 0)

        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        settingsWindow = settingsWindow or {}
        settingsWindow.x = new_x
        settingsWindow.y = new_y
        settingsWindow.width = ww
        settingsWindow.height = wh

        return
    end

    if not settingsActiveSlider then
        return
    end

    local mx, my = love.mouse.getPosition()
    local rect
    if settingsActiveSlider == "master" then
        rect = settingsRects.masterSlider
    elseif settingsActiveSlider == "music" then
        rect = settingsRects.musicSlider
    elseif settingsActiveSlider == "sfx" then
        rect = settingsRects.sfxSlider
    end

    if not rect then
        return
    end

    local px = mx
    if px < rect.x then px = rect.x end
    if px > rect.x + rect.w then px = rect.x + rect.w end

    local t = (px - rect.x) / rect.w
    applySliderValue(settingsActiveSlider, t)
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

    drawSettings()
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

    if settingsOpen then
        ensureSettingsState()

        local closeRect = settingsRects.close
        if closeRect and pointInRect(x, y, closeRect) then
            settingsOpen = false
            settingsActiveSlider = nil
            settingsDragActive = nil
            return nil
        end

        if handleSliderClick(x, y, settingsRects.masterSlider, "master") then
            return nil
        end
        if handleSliderClick(x, y, settingsRects.musicSlider, "music") then
            return nil
        end
        if handleSliderClick(x, y, settingsRects.sfxSlider, "sfx") then
            return nil
        end
        local nebulaRect = settingsRects.nebulaToggle
        if nebulaRect and pointInRect(x, y, nebulaRect) then
            settingsState.nebulaEnabled = not settingsState.nebulaEnabled
            if Config and Config.BACKGROUND then
                Config.BACKGROUND.ENABLE_NEBULA = settingsState.nebulaEnabled
            end
            return nil
        end

        local wx, wy, ww, wh = getSettingsWindowRect()
        local layout = Window.getLayout({ x = wx, y = wy, width = ww, height = wh })
        local tb = layout.titleBar
        if tb and pointInRect(x, y, tb) then
            settingsDragActive = true
            settingsDragOffsetX = x - wx
            settingsDragOffsetY = y - wy

            settingsWindow = settingsWindow or {}
            settingsWindow.width = ww
            settingsWindow.height = wh
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
                ensureSettingsState()
                settingsActiveSlider = nil
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
    settingsActiveSlider = nil
    settingsDragActive = nil
    saveOpen = false
end

return PauseMenu
