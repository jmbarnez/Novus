---@diagnostic disable: undefined-global
-- Pause Menu Overlay
-- Provides an escape menu with resume, save, settings, and exit options.

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Notifications = require('src.ui.notifications')

local PauseMenu = {
    _isOpen = false,
    _alpha = 0,
    _animSpeed = 6,
    _hoverIndex = nil,
    _selectedIndex = nil,
    _buttons = nil,
    _callbacks = {},
    _panel = {
        width = 420,
        paddingX = 40,
        paddingY = 36,
        headerHeight = 64,
        buttonHeight = 60,
        buttonSpacing = 16,
    },
    _saveSlot = 'slot1',
    _titleFont = nil,
    _buttonFont = nil,
}

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function PauseMenu:setCallbacks(callbacks)
    self._callbacks = callbacks or {}
end

function PauseMenu:getOpen()
    return self._isOpen
end

function PauseMenu:setOpen(state)
    state = not not state
    if self._isOpen == state then
        return
    end

    self._isOpen = state
    if state then
        self:_ensureButtons()
        self:_refreshFonts()
        self:_updateLayout()
        self._selectedIndex = self._selectedIndex or 1
        -- When the game loop is paused, UISystem.update won't advance the fade animation,
        -- so force the overlay visible immediately to ensure it renders.
        self._alpha = 1
    else
        self._hoverIndex = nil
        self._selectedIndex = nil
    end

    if self._callbacks.onVisibilityChanged then
        self._callbacks.onVisibilityChanged(state)
    end
end

function PauseMenu:toggle()
    self:setOpen(not self._isOpen)
end

function PauseMenu:setSaveSlot(slotName)
    if slotName and slotName ~= '' then
        self._saveSlot = slotName
    end
end

function PauseMenu:_ensureButtons()
    if self._buttons then
        return
    end

    self._buttons = {
        {
            label = 'Resume',
            action = function()
                self:setOpen(false)
                if self._callbacks.onRequestResume then
                    self._callbacks.onRequestResume()
                end
            end
        },
        {
            label = 'Save Game',
            action = function()
                self:_handleSave()
            end
        },
        {
            label = 'Settings',
            action = function()
                if self._callbacks.onRequestSettings then
                    self._callbacks.onRequestSettings()
                end
            end
        },
        {
            label = 'Exit to Main Menu',
            action = function()
                if self._callbacks.onRequestExit then
                    self._callbacks.onRequestExit()
                else
                    local Game = rawget(_G, 'Game')
                    if Game and Game.returnToMainMenu then
                        Game.returnToMainMenu()
                    end
                end
            end
        }
    }
end

function PauseMenu:_refreshFonts()
    self._titleFont = Theme.getFontBold(24)
    self._buttonFont = Theme.getFont(16)
end

function PauseMenu:_updateLayout()
    if not self._buttons then
        return
    end

    local screenW = Scaling.getCurrentWidth()
    local screenH = Scaling.getCurrentHeight()
    local panel = self._panel

    local panelWidth = clamp(panel.width, 320, math.max(320, screenW - 120))
    local buttonCount = #self._buttons
    local totalButtonHeight = buttonCount * panel.buttonHeight + (buttonCount - 1) * panel.buttonSpacing
    local panelHeight = panel.paddingY * 2 + panel.headerHeight + totalButtonHeight

    local x = math.floor((screenW - panelWidth) * 0.5)
    local y = math.floor((screenH - panelHeight) * 0.5)

    self._panel.computedX = x
    self._panel.computedY = y
    self._panel.computedWidth = panelWidth
    self._panel.computedHeight = panelHeight

    local buttonX = x + panel.paddingX
    local buttonWidth = panelWidth - panel.paddingX * 2
    local buttonY = y + panel.paddingY + panel.headerHeight

    for index, button in ipairs(self._buttons) do
        button.x = buttonX
        button.y = buttonY + (index - 1) * (panel.buttonHeight + panel.buttonSpacing)
        button.width = buttonWidth
        button.height = panel.buttonHeight
    end
end

function PauseMenu:_notify(text, duration)
    if Notifications and Notifications.addNotification then
        Notifications.addNotification({
            type = 'system',
            text = text,
            timer = duration or 3.0
        })
    else
        print(text)
    end
end

function PauseMenu:_handleSave()
    local Game = rawget(_G, 'Game')
    if not Game or not Game.save then
        self:_notify('Save system unavailable', 3.5)
        return
    end

    local ok, err = Game.save(self._saveSlot)
    if ok then
        local slotLabel = self._saveSlot or 'slot1'
        self:_notify(('Game saved to %s'):format(slotLabel), 3.5)
    else
        self:_notify(('Save failed: %s'):format(err or 'unknown error'), 4.5)
    end
end

function PauseMenu:update(dt)
    local target = self._isOpen and 1 or 0
    if self._alpha == target then
        return
    end

    local delta = dt * self._animSpeed
    if self._isOpen then
        self._alpha = math.min(1, self._alpha + delta)
    else
        self._alpha = math.max(0, self._alpha - delta)
    end
end

function PauseMenu:onResize()
    if self._buttons then
        self:_refreshFonts()
        self:_updateLayout()
    end
end

local function isPointInside(button, x, y)
    return x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height
end

function PauseMenu:mousepressed(x, y, button)
    if not self._isOpen then
        return false
    end

    self._hoverIndex = nil
    if button == 1 and self._buttons then
        for index, entry in ipairs(self._buttons) do
            if isPointInside(entry, x, y) then
                self._selectedIndex = index
                self:_activate(index)
                return true
            end
        end
    end

    return true -- Consume all clicks while open
end

function PauseMenu:mousereleased(_, _, _)
    if not self._isOpen then
        return false
    end
    return true
end

function PauseMenu:mousemoved(x, y, _, _)
    if not self._isOpen or not self._buttons then
        return
    end

    local hovered = nil
    for index, entry in ipairs(self._buttons) do
        if isPointInside(entry, x, y) then
            hovered = index
            break
        end
    end

    self._hoverIndex = hovered
    if hovered then
        self._selectedIndex = hovered
    end
end

function PauseMenu:wheelmoved(_, _)
    if not self._isOpen then
        return false
    end
    return true
end

function PauseMenu:keypressed(key)
    if not self._isOpen then
        return false
    end

    if key == 'up' or key == 'w' then
        if self._buttons and #self._buttons > 0 then
            local index = (self._selectedIndex or 1) - 1
            if index < 1 then index = #self._buttons end
            self._selectedIndex = index
        end
        return true
    elseif key == 'down' or key == 's' then
        if self._buttons and #self._buttons > 0 then
            local index = (self._selectedIndex or 1) + 1
            if index > #self._buttons then index = 1 end
            self._selectedIndex = index
        end
        return true
    elseif key == 'return' or key == 'space' then
        self:_activate(self._selectedIndex or 1)
        return true
    elseif key == 'escape' then
        self:setOpen(false)
        if self._callbacks.onRequestResume then
            self._callbacks.onRequestResume()
        end
        return true
    end

    return false
end

function PauseMenu:_activate(index)
    if not index or not self._buttons then
        return
    end

    local entry = self._buttons[index]
    if entry and entry.action then
        entry.action()
    end
end

function PauseMenu:draw()
    if (not self._isOpen) and self._alpha <= 0 then
        return
    end

    self:_updateLayout()

    local alpha = self._alpha
    if alpha <= 0 then
        return
    end

    local panel = self._panel
    local x = panel.computedX or 0
    local y = panel.computedY or 0
    local w = panel.computedWidth or panel.width
    local h = panel.computedHeight or (panel.width * 0.8)

    love.graphics.push('all')

    -- Dim background
    love.graphics.setColor(Theme.colors.overlay[1], Theme.colors.overlay[2], Theme.colors.overlay[3], alpha * Theme.colors.overlay[4])
    love.graphics.rectangle('fill', 0, 0, Scaling.getCurrentWidth(), Scaling.getCurrentHeight())

    -- Panel background (boxy style)
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], clamp(alpha * 0.95, 0, 1))
    love.graphics.rectangle('fill', x, y, w, h)

    -- Panel border (boxy style)
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h)

    -- Title
    love.graphics.setFont(self._titleFont)
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.printf('Paused', x, y + 12, w, 'center')

    -- Buttons
    love.graphics.setFont(self._buttonFont)
    for index, entry in ipairs(self._buttons or {}) do
        local isHovered = (self._hoverIndex == index) or (self._selectedIndex == index and not self._hoverIndex)
        local bx = entry.x
        local by = entry.y
        local bw = entry.width
        local bh = entry.height

        local baseColor = Theme.colors.bgMedium
        local hoverColor = Theme.colors.buttonHover

        if isHovered then
            love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], clamp(alpha, 0, 1))
        else
            love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], clamp(alpha * 0.95, 0, 1))
        end
        love.graphics.rectangle('fill', bx, by, bw, bh)

        love.graphics.setColor(Theme.colors.borderDark)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', bx, by, bw, bh)

        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.printf(entry.label, bx, by + bh / 2 - 12, bw, 'center')
    end

    love.graphics.pop()
end

return PauseMenu
