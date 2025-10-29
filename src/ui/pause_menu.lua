---@diagnostic disable: undefined-global
-- Pause Menu Overlay
-- Provides an escape menu with resume, save, settings, and exit options.

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Notifications = require('src.ui.notifications')

local PauseMenu = WindowBase:new({
    width = 420,
    height = 360,
    isOpen = false,
})

PauseMenu._alpha = 0
PauseMenu._animSpeed = 6
PauseMenu._hoverIndex = nil
PauseMenu._selectedIndex = nil
PauseMenu._buttons = nil
PauseMenu._callbacks = {}
PauseMenu._panel = {
    width = 420,
    paddingX = 40,
    paddingY = 28,
    headerHeight = 48,
    buttonHeight = 60,
    buttonSpacing = 16,
}
PauseMenu._saveSlot = 'slot1'
PauseMenu._titleFont = nil
PauseMenu._buttonFont = nil
PauseMenu._layout = nil

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function PauseMenu:setCallbacks(callbacks)
    self._callbacks = callbacks or {}
end

function PauseMenu:getOpen()
    return self.isOpen
end

function PauseMenu:setOpen(state)
    state = not not state
    if self.isOpen == state then
        return
    end

    if state then
        self:_ensureButtons()
        self:_refreshFonts()
        self:_updateLayout()
    end

    WindowBase.setOpen(self, state)

    if state then
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
    self:setOpen(not self.isOpen)
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
    local buttonCount = #self._buttons
    local totalButtonHeight = buttonCount * panel.buttonHeight + math.max(0, buttonCount - 1) * panel.buttonSpacing
    local topBarH = Theme.window.topBarHeight or 0
    local bottomBarH = Theme.window.bottomBarHeight or 0
    local contentHeight = panel.paddingY * 2 + panel.headerHeight + totalButtonHeight

    local width = clamp(panel.width, 320, math.max(320, screenW - 120))
    local height = topBarH + contentHeight + bottomBarH

    self.width = width
    self.height = height

    local posX = self.position and self.position.x or math.floor((screenW - width) * 0.5)
    local posY = self.position and self.position.y or math.floor((screenH - height) * 0.5)

    local buttonX = posX + panel.paddingX
    local buttonWidth = width - panel.paddingX * 2
    local buttonY = posY + topBarH + panel.paddingY + panel.headerHeight

    for index, button in ipairs(self._buttons) do
        button.x = buttonX
        button.y = buttonY + (index - 1) * (panel.buttonHeight + panel.buttonSpacing)
        button.width = buttonWidth
        button.height = panel.buttonHeight
    end

    self._layout = {
        panelX = posX,
        panelY = posY,
        panelWidth = width,
        titleY = posY + topBarH + panel.paddingY,
    }
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
    WindowBase.update(self, dt)

    local target = self.isOpen and 1 or 0
    if self._alpha == target then
        return
    end

    local delta = dt * self._animSpeed
    if self.isOpen then
        self._alpha = math.min(1, self._alpha + delta)
    else
        self._alpha = math.max(0, self._alpha - delta)
    end
end

function PauseMenu:onResize()
    WindowBase.onResize(self)
    if self._buttons then
        self:_refreshFonts()
        self:_updateLayout()
    end
end

local function isPointInside(button, x, y)
    return x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height
end

function PauseMenu:_isInsidePanel(x, y)
    if not self.position then
        return false
    end
    return x >= self.position.x and x <= self.position.x + (self.width or 0) and
           y >= self.position.y and y <= self.position.y + (self.height or 0)
end

function PauseMenu:mousepressed(x, y, button)
    if not self.isOpen then
        return false
    end

    self:_updateLayout()

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

    return self:_isInsidePanel(x, y)
end

function PauseMenu:mousereleased(x, y, button)
    if not self.isOpen then
        return false
    end

    self:_updateLayout()
    return self:_isInsidePanel(x, y)
end

function PauseMenu:mousemoved(x, y, _, _)
    if not self.isOpen or not self._buttons then
        return
    end

    self:_updateLayout()

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
    if not self.isOpen then
        return false
    end
    self:_updateLayout()
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    return self:_isInsidePanel(mx or 0, my or 0)
end

function PauseMenu:keypressed(key)
    if not self.isOpen then
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
    if (not self.isOpen) and self._alpha <= 0 then
        return
    end

    self:_updateLayout()

    local alpha = self._alpha
    if alpha <= 0 then
        return
    end

    local overlayColor = Theme.colors.overlay
    love.graphics.push('all')
    love.graphics.setColor(overlayColor[1] or 0, overlayColor[2] or 0, overlayColor[3] or 0, alpha * (overlayColor[4] or 1))
    love.graphics.rectangle('fill', 0, 0, Scaling.getCurrentWidth(), Scaling.getCurrentHeight())
    love.graphics.pop()

    if not self.position then
        return
    end

    WindowBase.draw(self)

    love.graphics.push('all')

    love.graphics.setFont(self._titleFont)
    love.graphics.setColor(unpack(Theme.colors.accent))
    local layout = self._layout or {}
    love.graphics.printf('Paused', self.position.x, (layout.titleY or (self.position.y + Theme.window.topBarHeight + 12)), self.width, 'center')

    for index, entry in ipairs(self._buttons or {}) do
        local isHovered = self._hoverIndex == index
        local isActive = (not self._hoverIndex) and self._selectedIndex == index
        Theme.drawPanelButton(entry.x, entry.y, entry.width, entry.height, entry.label, {
            isHovered = isHovered,
            isActive = isActive,
            alpha = clamp(alpha, 0, 1),
            font = self._buttonFont,
            idleAlpha = 0.95,
        })
    end

    love.graphics.pop()
end

return PauseMenu
