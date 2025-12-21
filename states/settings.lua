local Gamestate = require("lib.hump.gamestate")
local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local Settings = require("game.settings")

local pointInRect = Rect.pointInRect

local SettingsState = {}

function SettingsState:init()
    self.frame = WindowFrame.new()
    self.hover = nil
    self.pressed = nil
    self.bounds = nil
    self.listening = nil -- { action = "thrust", index = 1 } (waiting for key press)

    -- FPS Options
    self.fpsOptions = { 30, 60, 120, 144, 0 } -- 0 is Unlimited
    self.fpsIndex = 2
end

function SettingsState:enter(from)
    self.from = from -- Usually Pause state
    self.hover = nil
    self.pressed = nil
    self.bounds = nil
    self.listening = nil

    -- Initialize FPS index from settings
    local currentFps = Settings.get("maxFps") or 60
    self.fpsIndex = 5 -- Default to Unlimited if not found
    for i, fps in ipairs(self.fpsOptions) do
        if fps == currentFps then
            self.fpsIndex = i
            break
        end
    end
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

    -- FPS Control
    local fpsY = contentY
    bounds.fpsLabel = { x = contentX, y = fpsY, w = 100, h = 24 }
    bounds.fpsValue = { x = contentX + 110, y = fpsY, w = 140, h = 24 }
    bounds.fpsLeft = { x = contentX + 110, y = fpsY, w = 24, h = 24 }
    bounds.fpsRight = { x = contentX + 110 + 140 - 24, y = fpsY, w = 24, h = 24 }

    -- Keybinds Header
    local listY = fpsY + 40
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

    -- FPS Arrows
    if pointInRect(x, y, b.fpsLeft) then
        self.fpsIndex = self.fpsIndex - 1
        if self.fpsIndex < 1 then self.fpsIndex = #self.fpsOptions end
        Settings.set("maxFps", self.fpsOptions[self.fpsIndex])
        return true
    end
    if pointInRect(x, y, b.fpsRight) then
        self.fpsIndex = self.fpsIndex + 1
        if self.fpsIndex > #self.fpsOptions then self.fpsIndex = 1 end
        Settings.set("maxFps", self.fpsOptions[self.fpsIndex])
        return true
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
    if pointInRect(x, y, b.fpsLeft) then self.hover = "fpsLeft" end
    if pointInRect(x, y, b.fpsRight) then self.hover = "fpsRight" end

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

    -- FPS Arrows
    local fpsText = self.fpsOptions[self.fpsIndex] == 0 and "Unlimited" or tostring(self.fpsOptions[self.fpsIndex])
    local tw = font:getWidth(fpsText)
    love.graphics.print(fpsText, b.fpsValue.x + (b.fpsValue.w - tw) / 2, b.fpsValue.y + 4)

    local function drawArrow(rect, dir, hover)
        love.graphics.setColor(1, 1, 1, hover and 1 or 0.5)
        local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
        if dir == "left" then
            love.graphics.polygon("fill", cx + 4, cy - 6, cx + 4, cy + 6, cx - 4, cy)
        else
            love.graphics.polygon("fill", cx - 4, cy - 6, cx - 4, cy + 6, cx + 4, cy)
        end
    end
    drawArrow(b.fpsLeft, "left", self.hover == "fpsLeft")
    drawArrow(b.fpsRight, "right", self.hover == "fpsRight")

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

    love.graphics.pop()
end

return SettingsState
