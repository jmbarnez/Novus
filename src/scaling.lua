-- scaling.lua - universal scaling utilities for game/UI rendering

local Scaling = {}

-- Reference resolution (designed for 1080p, easily modifiable)
Scaling.REFERENCE_WIDTH = 1920
Scaling.REFERENCE_HEIGHT = 1080

Scaling.windowWidth = love.graphics.getWidth()
Scaling.windowHeight = love.graphics.getHeight()

Scaling._scaleX = Scaling.windowWidth / Scaling.REFERENCE_WIDTH
Scaling._scaleY = Scaling.windowHeight / Scaling.REFERENCE_HEIGHT

Scaling.maintainAspect = true -- set false to stretch to any shape

function Scaling.update()
    Scaling.windowWidth = love.graphics.getWidth()
    Scaling.windowHeight = love.graphics.getHeight()
    Scaling._scaleX = Scaling.windowWidth / Scaling.REFERENCE_WIDTH
    Scaling._scaleY = Scaling.windowHeight / Scaling.REFERENCE_HEIGHT
end

function Scaling.getScale()
    if Scaling.maintainAspect then
        local s = math.min(Scaling._scaleX, Scaling._scaleY)
        return s, s
    else
        return Scaling._scaleX, Scaling._scaleY
    end
end

function Scaling.scaleX(x)
    local s, _ = Scaling.getScale()
    return x * s
end

function Scaling.scaleY(y)
    local _, s = Scaling.getScale()
    return y * s
end

function Scaling.scaleSize(size)
    if type(size) ~= 'number' then return size end
    local s, _ = Scaling.getScale()
    return size * s
end

function Scaling.toScreen(x, y)
    local s, _ = Scaling.getScale()
    return x * s, y * s
end

function Scaling.toGame(x, y)
    local s, _ = Scaling.getScale()
    return x / s, y / s
end

return Scaling
