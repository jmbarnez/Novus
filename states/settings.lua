local Gamestate = require("lib.hump.gamestate")
local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local Settings = require("game.settings")
local Sound = require("game.sound")

local pointInRect = Rect.pointInRect

local SettingsState = {}

function SettingsState:init()
    self.frame = WindowFrame.new()
    self.hover = nil
    self.pressed = nil
    self.bounds = nil
    self.listening = nil -- { action = "thrust", index = 1 } (waiting for key press)
    self.dragging = nil -- { channel = "master" }

    -- FPS Options
    self.fpsOptions = { 30, 60, 120, 144, 240, 360, 0 } -- 0 is Unlimited
    self.fpsIndex = 2
    self.fpsDropdownOpen = false
end

function SettingsState:enter(from)
    self.from = from -- Usually Pause state
    self.hover = nil
    self.pressed = nil
    self.bounds = nil
    self.listening = nil
    self.dragging = nil
    self.fpsDropdownOpen = false

    -- Initialize FPS index from settings
    local currentFps = Settings.get("maxFps") or 60
    self.fpsIndex = 7 -- Default to Unlimited if not found
    for i, fps in ipairs(self.fpsOptions) do
        if fps == currentFps then
            self.fpsIndex = i
            break
        end
    end

    -- Sync audio volumes with saved settings (ensures sliders reflect persisted values)
    Sound.load()
end

function SettingsState:_ctx()
    local screenW, screenH = love.graphics.getDimensions()
    return {
        theme = Theme,
        screenW = screenW,
        screenH = screenH,
        layout = {
            margin = (Theme.hud and Theme.hud.layout and Theme.hud.layout.margin) or 16,
        },
    }
end

function SettingsState:_layout(ctx)
    local screenW, screenH = ctx.screenW, ctx.screenH
    local hudTheme = Theme.hud
    local margin = (hudTheme.layout and hudTheme.layout.margin) or 16
    local pad = 12
    local headerH = 28
    local footerH = 0

    local winW = math.min(500, math.floor(screenW * 0.60))
    local winH = math.min(600, math.floor(screenH * 0.80))

    local x0 = math.floor((screenW - winW) * 0.5)
    local y0 = math.floor((screenH - winH) * 0.5)

    if self.frame.x == nil or self.frame.y == nil then
        self.frame.x = x0
        self.frame.y = y0
    end

    local bounds = self.frame:compute(ctx, winW, winH, {
        headerH = headerH,
        footerH = footerH,
        closeSize = 18,
        closePad = 6,
        margin = margin,
    })

    bounds.pad = pad
    local contentX = bounds.x + pad
    local contentY = bounds.y + headerH + 12
    local contentW = bounds.w - pad * 2
    local btnH = 30

    -- Back Button
    bounds.btnBack = {
        x = bounds.x + (bounds.w - 120) / 2,
        y = bounds.y + bounds.h - pad - btnH,
        w = 120,
        h = btnH
    }

    -- FPS Control (Dropdown)
    local fpsY = contentY
    local dropdownW = 140
    local dropdownH = 24
    local optionH = 24
    bounds.fpsLabel = { x = contentX, y = fpsY, w = 100, h = dropdownH }
    bounds.fpsDropdown = { x = contentX + 110, y = fpsY, w = dropdownW, h = dropdownH }

    -- Dropdown options (positioned below the dropdown button)
    bounds.fpsOptions = {}
    for i = 1, #self.fpsOptions do
        bounds.fpsOptions[i] = {
            x = contentX + 110,
            y = fpsY + dropdownH + (i - 1) * optionH,
            w = dropdownW,
            h = optionH
        }
    end
    bounds.fpsOptionsPanel = {
        x = contentX + 110,
        y = fpsY + dropdownH,
        w = dropdownW,
        h = #self.fpsOptions * optionH
    }

    -- VSync Control
    local vsyncY = fpsY + 32
    bounds.vsyncLabel = { x = contentX, y = vsyncY, w = 100, h = 24 }
    bounds.vsyncBtn = { x = contentX + 110, y = vsyncY, w = 140, h = 24 }

    -- Sound Section
    local soundY = vsyncY + 40
    bounds.soundRows = {}
    local soundRowH = 28
    local channels = {
        { label = "Master", channel = "master" },
        { label = "SFX", channel = "sfx" },
        { label = "Music", channel = "music" },
    }
    for i, ch in ipairs(channels) do
        local y = soundY + (i - 1) * (soundRowH + 6)
        bounds.soundRows[i] = {
            label = { x = contentX, y = y, w = 100, h = soundRowH },
            slider = { x = contentX + 110, y = y + 4, w = 180, h = soundRowH - 8 },
            channel = ch.channel,
            text = ch.label,
        }
    end

    -- Keybinds Header
    local listY = soundY + (#bounds.soundRows * (soundRowH + 6)) + 20
    bounds.listHeader = { x = contentX, y = listY, w = contentW, h = 24 }

    -- Keybinds List
    bounds.binds = {}
    local rowH = 32
    local cy = listY + 30
    local controls = Settings.get("controls")

    -- Sort actions for consistent order
    local actions = {}
    for k in pairs(controls) do table.insert(actions, k) end
    table.sort(actions)

    for i, action in ipairs(actions) do
        local keys = controls[action]
        local actionLabel = action:gsub("_", " "):gsub("^%l", string.upper)

        -- Action Label
        table.insert(bounds.binds, {
            type = "label",
            text = actionLabel,
            rect = { x = contentX, y = cy, w = 140, h = 24 }
        })

        -- Key 1
        table.insert(bounds.binds, {
            type = "key",
            action = action,
            index = 1,
            key = keys[1] or "---",
            rect = { x = contentX + 150, y = cy, w = 120, h = 24 }
        })

        -- Key 2
        table.insert(bounds.binds, {
            type = "key",
            action = action,
            index = 2,
            key = keys[2] or "---",
            rect = { x = contentX + 280, y = cy, w = 120, h = 24 }
        })

        cy = cy + rowH
    end

    self.bounds = bounds
    return bounds
end

function SettingsState:keypressed(key)
    if self.listening then
        local action = self.listening.action
        local index = self.listening.index
        local controls = Settings.get("controls")

        -- Prevent duplicates binding same key? Or allow it?
        -- For now, simple set.
        if key == "escape" then
            -- Cancel binding
            self.listening = nil
        else
            -- Bind key
            local newBind = "key:" .. key
            controls[action][index] = newBind
            Settings.setControl(action, controls[action])
            self.listening = nil
        end
        return
    end

    if key == "escape" then
        Gamestate.pop()
    end
end

function SettingsState:mousepressed(x, y, button)
    if self.listening then
        local action = self.listening.action
        local index = self.listening.index
        local controls = Settings.get("controls")

        -- Bind mouse button
        local newBind = "mouse:" .. button
        controls[action][index] = newBind
        Settings.setControl(action, controls[action])
        self.listening = nil
        return true
    end

    local ctx = self:_ctx()
    local b = self:_layout(ctx)

    if not pointInRect(x, y, b) then return false end

    -- Handle window drag/close
    local consumed, didClose = self.frame:mousepressed(ctx, b, x, y, button)
    if didClose then
        Gamestate.pop()
        return true
    end
    if consumed then return true end

    -- Back Button
    if pointInRect(x, y, b.btnBack) then
        self.pressed = "Back"
        return true
    end

    -- FPS Dropdown
    if self.fpsDropdownOpen then
        -- Check if clicked on an option
        for i, optRect in ipairs(b.fpsOptions) do
            if pointInRect(x, y, optRect) then
                self.fpsIndex = i
                Settings.set("maxFps", self.fpsOptions[i])
                self.fpsDropdownOpen = false
                return true
            end
        end
        -- Clicked outside dropdown, close it
        self.fpsDropdownOpen = false
        return true
    else
        -- Toggle dropdown open
        if pointInRect(x, y, b.fpsDropdown) then
            self.fpsDropdownOpen = true
            return true
        end
    end

    -- VSync Toggle
    if pointInRect(x, y, b.vsyncBtn) then
        local current = Settings.get("vsync")
        Settings.set("vsync", not current)
        love.window.setVSync(not current and 1 or 0)
        return true
    end

    -- Sound Controls (slider grab)
    for _, row in ipairs(b.soundRows) do
        if pointInRect(x, y, row.slider) then
            local pct = (x - row.slider.x) / row.slider.w
            pct = math.max(0, math.min(1, pct))
            Sound.setVolume(row.channel, pct)
            self.dragging = { channel = row.channel, slider = row.slider }
            return true
        end
    end

    -- Keybinds
    for _, item in ipairs(b.binds) do
        if item.type == "key" and pointInRect(x, y, item.rect) then
            self.listening = { action = item.action, index = item.index }
            return true
        end
    end

    return true
end

function SettingsState:mousereleased(x, y, button)
    if self.listening then return end

    local ctx = self:_ctx()
    local b = self:_layout(ctx)
    self.frame:mousereleased(ctx, x, y, button)

    self.dragging = nil

    if self.pressed == "Back" and pointInRect(x, y, b.btnBack) then
        Gamestate.pop()
    end
    self.pressed = nil
end

function SettingsState:mousemoved(x, y, dx, dy)
    if self.listening then return end

    local ctx = self:_ctx()
    local b = self:_layout(ctx)
    self.frame:mousemoved(ctx, x, y, dx, dy)

    self.hover = nil
    if pointInRect(x, y, b.btnBack) then self.hover = "Back" end
    if pointInRect(x, y, b.fpsDropdown) then self.hover = "fpsDropdown" end
    if self.fpsDropdownOpen then
        for i, optRect in ipairs(b.fpsOptions) do
            if pointInRect(x, y, optRect) then
                self.hover = "fpsOption" .. i
            end
        end
    end
    if pointInRect(x, y, b.vsyncBtn) then self.hover = "vsync" end
    for _, row in ipairs(b.soundRows) do
        if pointInRect(x, y, row.slider) then self.hover = row.slider end
    end

    if self.dragging and self.dragging.slider then
        local slider = self.dragging.slider
        local pct = (x - slider.x) / slider.w
        pct = math.max(0, math.min(1, pct))
        Sound.setVolume(self.dragging.channel, pct)
    end

    for _, item in ipairs(b.binds) do
        if item.type == "key" and pointInRect(x, y, item.rect) then
            self.hover = item -- store the item itself as hover target
        end
    end
end

function SettingsState:draw()
    if self.from and self.from.draw then
        self.from:draw()
    end

    love.graphics.push("all")

    local ctx = self:_ctx()
    local b = self:_layout(ctx)
    local colors = Theme.hud.colors
    local r = Theme.hud.panelStyle.radius

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, ctx.screenW, ctx.screenH)

    -- Window Frame
    self.frame:draw(ctx, b, { title = "SETTINGS", titlePad = b.pad })

    local font = love.graphics.getFont()
    local mx, my = love.mouse.getPosition()

    -- FPS Control
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Max FPS:", b.fpsLabel.x, b.fpsLabel.y + 4)

    -- FPS Dropdown Button
    local fpsText = self.fpsOptions[self.fpsIndex] == 0 and "Unlimited" or tostring(self.fpsOptions[self.fpsIndex])
    local tw = font:getWidth(fpsText)
    local isDropdownHover = self.hover == "fpsDropdown"

    -- Dropdown background
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", b.fpsDropdown.x, b.fpsDropdown.y, b.fpsDropdown.w, b.fpsDropdown.h, 4)

    -- Dropdown border
    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
        (isDropdownHover or self.fpsDropdownOpen) and 0.8 or 0.4)
    love.graphics.rectangle("line", b.fpsDropdown.x, b.fpsDropdown.y, b.fpsDropdown.w, b.fpsDropdown.h, 4)

    -- Dropdown text
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(fpsText, b.fpsDropdown.x + 8, b.fpsDropdown.y + 4)

    -- Dropdown arrow indicator
    local arrowX = b.fpsDropdown.x + b.fpsDropdown.w - 16
    local arrowY = b.fpsDropdown.y + b.fpsDropdown.h / 2
    love.graphics.setColor(1, 1, 1, 0.7)
    if self.fpsDropdownOpen then
        -- Up arrow
        love.graphics.polygon("fill", arrowX - 4, arrowY + 2, arrowX + 4, arrowY + 2, arrowX, arrowY - 4)
    else
        -- Down arrow
        love.graphics.polygon("fill", arrowX - 4, arrowY - 2, arrowX + 4, arrowY - 2, arrowX, arrowY + 4)
    end



    -- VSync Control
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("VSync:", b.vsyncLabel.x, b.vsyncLabel.y + 4)

    local vsyncOn = Settings.get("vsync")
    local vsyncText = vsyncOn and "Enabled" or "Disabled"
    local vw = font:getWidth(vsyncText)

    local isVsyncHover = self.hover == "vsync"
    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
        isVsyncHover and 0.8 or 0.4)
    love.graphics.rectangle("line", b.vsyncBtn.x, b.vsyncBtn.y, b.vsyncBtn.w, b.vsyncBtn.h, 4)

    love.graphics.setColor(1, 1, 1, isVsyncHover and 1 or 0.9)
    love.graphics.print(vsyncText, b.vsyncBtn.x + (b.vsyncBtn.w - vw) / 2, b.vsyncBtn.y + 4)

    -- Sound Section
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Sound", b.soundRows[1].label.x, b.soundRows[1].label.y - 20)
    for _, row in ipairs(b.soundRows) do
        local val = Sound.getVolume(row.channel)
        local pctText = string.format("%d%%", math.floor(val * 100 + 0.5))
        local tw = font:getWidth(pctText)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(row.text .. ":", row.label.x, row.label.y + 4)

        local slider = row.slider
        local isHover = self.hover == slider or (self.dragging and self.dragging.slider == slider)
        local thumbX = slider.x + val * slider.w

        -- Track
        love.graphics.setColor(0.12, 0.12, 0.12, 1)
        love.graphics.rectangle("fill", slider.x, slider.y, slider.w, slider.h, 3)
        love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], 0.5)
        love.graphics.rectangle("line", slider.x, slider.y, slider.w, slider.h, 3)

        -- Fill
        love.graphics.setColor(0.3, 0.6, 1, 0.6)
        love.graphics.rectangle("fill", slider.x, slider.y, slider.w * val, slider.h, 3)

        -- Thumb
        love.graphics.setColor(1, 1, 1, isHover and 1 or 0.8)
        love.graphics.rectangle("fill", thumbX - 6, slider.y - 3, 12, slider.h + 6, 3)
        love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], isHover and 0.9 or 0.5)
        love.graphics.rectangle("line", thumbX - 6, slider.y - 3, 12, slider.h + 6, 3)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(pctText, slider.x + slider.w + 8, slider.y - 2)
    end

    -- Keybinds Header
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Keybindings", b.listHeader.x, b.listHeader.y)
    love.graphics.line(b.listHeader.x, b.listHeader.y + 20, b.listHeader.x + b.listHeader.w, b.listHeader.y + 20)

    -- Bindings List
    for _, item in ipairs(b.binds) do
        if item.type == "label" then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.print(item.text, item.rect.x, item.rect.y + 4)
        elseif item.type == "key" then
            local isListening = self.listening and self.listening.action == item.action and
                self.listening.index == item.index
            local isHover = self.hover == item

            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.rectangle("fill", item.rect.x, item.rect.y, item.rect.w, item.rect.h, 4)

            love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
                (isHover or isListening) and 0.8 or 0.4)
            love.graphics.rectangle("line", item.rect.x, item.rect.y, item.rect.w, item.rect.h, 4)

            local text = isListening and "Press key..." or item.key
            if not isListening then
                text = text:gsub("key:", ""):gsub("mouse:", "MB ")
            end

            local w = font:getWidth(text)
            love.graphics.setColor(1, 1, 1, isListening and 1 or 0.8)
            love.graphics.print(text, item.rect.x + (item.rect.w - w) / 2, item.rect.y + 4)
        end
    end

    -- Back Button
    local isHover = pointInRect(mx, my, b.btnBack)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], isHover and 1 or 0.8)
    love.graphics.rectangle("line", b.btnBack.x, b.btnBack.y, b.btnBack.w, b.btnBack.h, r)
    local backText = "Back"
    local bw = font:getWidth(backText)
    love.graphics.print(backText, b.btnBack.x + (b.btnBack.w - bw) / 2, b.btnBack.y + 6)

    -- FPS Dropdown options panel (drawn last to render on top of everything)
    if self.fpsDropdownOpen then
        -- Panel background
        love.graphics.setColor(0.08, 0.08, 0.08, 0.98)
        love.graphics.rectangle("fill", b.fpsOptionsPanel.x, b.fpsOptionsPanel.y, b.fpsOptionsPanel.w,
            b.fpsOptionsPanel.h, 4)

        -- Panel border
        love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], 0.6)
        love.graphics.rectangle("line", b.fpsOptionsPanel.x, b.fpsOptionsPanel.y, b.fpsOptionsPanel.w,
            b.fpsOptionsPanel.h, 4)

        -- Draw each option
        for i, optRect in ipairs(b.fpsOptions) do
            local optText = self.fpsOptions[i] == 0 and "Unlimited" or tostring(self.fpsOptions[i])
            local isHovered = self.hover == "fpsOption" .. i
            local isSelected = i == self.fpsIndex

            -- Highlight on hover
            if isHovered then
                love.graphics.setColor(0.3, 0.5, 0.8, 0.4)
                love.graphics.rectangle("fill", optRect.x + 2, optRect.y, optRect.w - 4, optRect.h)
            end

            -- Option text
            if isSelected then
                love.graphics.setColor(0.4, 0.8, 1, 1)
            else
                love.graphics.setColor(1, 1, 1, isHovered and 1 or 0.8)
            end
            love.graphics.print(optText, optRect.x + 8, optRect.y + 4)

            -- Checkmark for selected
            if isSelected then
                love.graphics.setColor(0.4, 0.8, 1, 1)
                love.graphics.print("✓", optRect.x + optRect.w - 20, optRect.y + 4)
            end
        end
    end

    love.graphics.pop()
end

return SettingsState
