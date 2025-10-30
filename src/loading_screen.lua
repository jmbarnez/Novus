---@diagnostic disable: undefined-global
-- src/loading_screen.lua
-- Simple loading screen module

local loading_screen = {}
local Theme = require('src.ui.plasma_theme')

local loadingText = "Loading..."

function loading_screen.draw()
    love.graphics.clear(0, 0, 0)
    local width, height = love.graphics.getDimensions()
    local font = Theme.getFontBold(48)
    love.graphics.setFont(font)
    local c = Theme.colors.accent
    love.graphics.setColor(c[1], c[2], c[3], c[4])
    love.graphics.printf(loadingText, 0, height/2 - font:getHeight()/2, width, "center")
end

return loading_screen