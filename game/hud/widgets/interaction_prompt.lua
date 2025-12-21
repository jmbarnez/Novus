--- Interaction prompt HUD widget
--- Shows contextual interaction prompts like "[E] Dock" when near interactable objects

local Theme = require("game.theme")

local InteractionPrompt = {}

function InteractionPrompt.draw(ctx)
    if not ctx then return end

    local prompt = ctx.interactionPrompt
    if not prompt or not prompt.text then return end

    local screenW, screenH = love.graphics.getDimensions()
    local font = love.graphics.getFont()

    local text = prompt.text
    local tw = font:getWidth(text)
    local th = font:getHeight()

    -- Position at bottom center of screen
    local x = screenW / 2 - tw / 2
    local y = screenH - 120

    -- Background box
    love.graphics.push("all")
    love.graphics.setColor(0.05, 0.10, 0.18, 0.85)
    love.graphics.rectangle("fill", x - 16, y - 8, tw + 32, th + 16, 6)

    -- Border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.00, 0.85, 0.75, 0.7)
    love.graphics.rectangle("line", x - 16, y - 8, tw + 32, th + 16, 6)

    -- Text
    love.graphics.setColor(0.00, 1.00, 0.85, 1.0)
    love.graphics.print(text, x, y)

    love.graphics.pop()
end

return InteractionPrompt
