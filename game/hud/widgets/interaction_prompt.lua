--- Interaction prompt HUD widget
--- Shows contextual interaction prompts like "[E] Dock" or "[E] Refine" when near interactable objects

local Theme = require("game.theme")

local InteractionPrompt = {}

function InteractionPrompt.draw(ctx)
    if not ctx then return end

    -- Check for either dock prompt or refinery prompt
    local prompt = ctx.interactionPrompt or ctx.refineryPrompt
    if not prompt or not prompt.text then return end

    local screenW, screenH = love.graphics.getDimensions()
    local font = love.graphics.getFont()

    local text = prompt.text
    local tw = font:getWidth(text)
    local th = font:getHeight()

    -- Position at bottom center of screen
    local x = screenW / 2 - tw / 2
    local y = screenH - 120

    -- Use different colors for refinery vs dock
    local isRefinery = ctx.refineryPrompt and not ctx.interactionPrompt

    -- Background box
    love.graphics.push("all")
    if isRefinery then
        love.graphics.setColor(0.15, 0.10, 0.05, 0.85)
    else
        love.graphics.setColor(0.05, 0.10, 0.18, 0.85)
    end
    love.graphics.rectangle("fill", x - 16, y - 8, tw + 32, th + 16, 6)

    -- Border
    love.graphics.setLineWidth(2)
    if isRefinery then
        love.graphics.setColor(0.95, 0.65, 0.25, 0.7)
    else
        love.graphics.setColor(0.00, 0.85, 0.75, 0.7)
    end
    love.graphics.rectangle("line", x - 16, y - 8, tw + 32, th + 16, 6)

    -- Text
    if isRefinery then
        love.graphics.setColor(1.00, 0.80, 0.40, 1.0)
    else
        love.graphics.setColor(0.00, 1.00, 0.85, 1.0)
    end
    love.graphics.print(text, x, y)

    love.graphics.pop()
end

return InteractionPrompt
