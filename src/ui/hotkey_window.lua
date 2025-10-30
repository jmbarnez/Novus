---@diagnostic disable: undefined-global
-- Small Hotkey Reference Window
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local HotkeyConfig = require('src.hotkey_config')

local HotkeyWindow = WindowBase:new{
    width = 480,
    height = 140,
    isOpen = false,
    animAlphaSpeed = 6.0,
    _initialized = false,
    entries = nil,
}

function HotkeyWindow:initialize()
    if self._initialized then return end

    -- Gather hotkey entries and compute a height that fits them
    self.entries = HotkeyConfig.getAllHotkeys() or {}
    local font = Theme.getFont(Theme.fonts.small)
    local lineHeight = (font and font:getHeight() or 14) + 6
    local paddingY = 12
    local contentH = #self.entries * lineHeight
    local totalH = (Theme.window.topBarHeight or 28) + (Theme.window.bottomBarHeight or 0) + paddingY * 2 + contentH

    -- Allow the window to grow to fit contents but cap to screen height
    local maxH = math.max(200, (Scaling.getCurrentHeight() or 720) - 48)
    self.height = math.min(totalH, maxH)

    -- Center on screen after resizing
    if self.autoCenter then
        self:centerOnScreen()
    end

    self._initialized = true
end

function HotkeyWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if state then
        -- Ensure fully visible when opened
        self.animAlpha = 1
        self.animAlphaActive = false
        if love and love.timer then self._lastAnimTimestamp = love.timer.getTime() end
    end
end

function HotkeyWindow:getOpen()
    return self.isOpen
end

function HotkeyWindow:toggle()
    self:setOpen(not self.isOpen)
end

function HotkeyWindow:draw()
    if not self:isVisible() then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end

    -- Soft backdrop so it reads as a small floating panel
    WindowBase.draw(self)
    if not self.position then return end

    local x, y = self.position.x, self.position.y
    local w, h = self.width, self.height

    love.graphics.push('all')
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], (Theme.colors.text[4] or 1) * alpha)
    love.graphics.printf("Hotkeys", x + 12, y + 6, w - 24, "left")

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    local entries = self.entries or HotkeyConfig.getAllHotkeys()
    local font = Theme.getFont(Theme.fonts.small)
    local lineH = (font and font:getHeight() or 14) + 6
    local paddingY = 12
    local startY = y + (Theme.window.topBarHeight or 28) + paddingY

    for i, entry in ipairs(entries or {}) do
        local text = HotkeyConfig.getDisplayText(entry.action)
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], ((Theme.colors.textSecondary[4] or 1) * alpha))
        love.graphics.printf(text, x + 14, startY + (i - 1) * lineH, w - 28, "left")
    end

    -- Close button (draw 'X')
    self:drawCloseButton(x, y, alpha)
    love.graphics.pop()
end

return HotkeyWindow


