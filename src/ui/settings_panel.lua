local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"
local SettingsManager = require "src.managers.settings_manager"

local SettingsPanel = {}

local state
local rects = {}
local activeSlider
local windowRect
local dragActive
local dragOffsetX
local dragOffsetY

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function ensureState()
    if state then
        return
    end

    state = SettingsManager.get_state()
end

local function getWindowRect()
    local sw, sh = love.graphics.getDimensions()
    local width = math.min(420, sw * 0.6)
    local height = 320

    if windowRect then
        local x = windowRect.x or (sw - width) * 0.5
        local y = windowRect.y or (sh - height) * 0.5
        windowRect.width = width
        windowRect.height = height
        return x, y, width, height
    end

    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

local function drawSliderBase(rect, value)
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
    drawSliderBase(rect, value)

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

    ensureState()

    if kind == "master" then
        state.masterVolume = t
        SettingsManager.set_master_volume(t)
    elseif kind == "music" then
        state.musicVolume = t
        SettingsManager.set_music_volume(t)
    elseif kind == "sfx" then
        state.sfxVolume = t
        SettingsManager.set_sfx_volume(t)
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
    activeSlider = kind
    return true
end

function SettingsPanel.reset()
    activeSlider = nil
    dragActive = nil
end

function SettingsPanel.update(dt)
    if not activeSlider and not dragActive then
        return
    end

    if not love.mouse.isDown(1) then
        activeSlider = nil
        dragActive = nil
        return
    end

    if dragActive then
        local mx, my = love.mouse.getPosition()
        local sw, sh = love.graphics.getDimensions()
        local _, _, ww, wh = getWindowRect()

        local new_x = mx - (dragOffsetX or 0)
        local new_y = my - (dragOffsetY or 0)

        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        windowRect = windowRect or {}
        windowRect.x = new_x
        windowRect.y = new_y
        windowRect.width = ww
        windowRect.height = wh

        return
    end

    if not activeSlider then
        return
    end

    local mx, my = love.mouse.getPosition()
    local rect
    if activeSlider == "master" then
        rect = rects.masterSlider
    elseif activeSlider == "music" then
        rect = rects.musicSlider
    elseif activeSlider == "sfx" then
        rect = rects.sfxSlider
    end

    if not rect then
        return
    end

    local px = mx
    if px < rect.x then px = rect.x end
    if px > rect.x + rect.w then px = rect.x + rect.w end

    local t = (px - rect.x) / rect.w
    applySliderValue(activeSlider, t)
end

function SettingsPanel.draw()
    ensureState()

    local wx, wy, ww, wh = getWindowRect()
    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Settings",
        bottomText = nil,
        showClose = true,
    })

    rects.close = layout.close
    rects.titleBar = layout.titleBar

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
    rects.masterSlider = masterRect
    drawSliderWithValue(masterRect, state.masterVolume)

    local musicLabelY = masterRectY + sliderHeight + 28
    love.graphics.print("Music Volume", sliderX, musicLabelY)
    local musicRectY = musicLabelY + font:getHeight() + 6

    local musicRect = {
        x = sliderX,
        y = musicRectY,
        w = sliderWidth,
        h = sliderHeight,
    }
    rects.musicSlider = musicRect
    drawSliderWithValue(musicRect, state.musicVolume)

    local sfxLabelY = musicRectY + sliderHeight + 28
    love.graphics.print("SFX Volume", sliderX, sfxLabelY)
    local sfxRectY = sfxLabelY + font:getHeight() + 6

    local sfxRect = {
        x = sliderX,
        y = sfxRectY,
        w = sliderWidth,
        h = sliderHeight,
    }
    rects.sfxSlider = sfxRect
    drawSliderWithValue(sfxRect, state.sfxVolume)

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
    rects.nebulaToggle = nebulaRect

    local enabled = state.nebulaEnabled
    local label = enabled and "Nebula: ON" or "Nebula: OFF"
    local btnState = enabled and "active" or "default"
    Theme.drawButton(nebulaRect.x, nebulaRect.y, nebulaRect.w, nebulaRect.h, label, btnState, font)
end

function SettingsPanel.mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end

    ensureState()

    local closeRect = rects.close
    if closeRect and pointInRect(x, y, closeRect) then
        return "close"
    end

    if handleSliderClick(x, y, rects.masterSlider, "master") then
        return true
    end
    if handleSliderClick(x, y, rects.musicSlider, "music") then
        return true
    end
    if handleSliderClick(x, y, rects.sfxSlider, "sfx") then
        return true
    end

    local nebulaRect = rects.nebulaToggle
    if nebulaRect and pointInRect(x, y, nebulaRect) then
        state.nebulaEnabled = not state.nebulaEnabled
        SettingsManager.set_nebula_enabled(state.nebulaEnabled)
        return true
    end

    local wx, wy, ww, wh = getWindowRect()
    local layout = Window.getLayout({ x = wx, y = wy, width = ww, height = wh })
    local tb = layout.titleBar
    if tb and pointInRect(x, y, tb) then
        dragActive = true
        dragOffsetX = x - wx
        dragOffsetY = y - wy

        windowRect = windowRect or {}
        windowRect.width = ww
        windowRect.height = wh
        return true
    end

    return false
end

return SettingsPanel
