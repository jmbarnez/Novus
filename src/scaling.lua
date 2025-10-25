---@diagnostic disable: undefined-global
-- scaling.lua - universal scaling utilities for game/UI rendering

local Scaling = {}

-- Reference resolution (matches display resolution)
Scaling.REFERENCE_WIDTH = 1600
Scaling.REFERENCE_HEIGHT = 900

Scaling.windowWidth = love.graphics.getWidth()
Scaling.windowHeight = love.graphics.getHeight()

Scaling._scaleX = Scaling.windowWidth / Scaling.REFERENCE_WIDTH
Scaling._scaleY = Scaling.windowHeight / Scaling.REFERENCE_HEIGHT

Scaling.maintainAspect = true -- set false to stretch to any shape

function Scaling.update()
    Scaling.windowWidth = love.graphics.getWidth()
    Scaling.windowHeight = love.graphics.getHeight()
    -- Update reference resolution to match current window size for proper scaling
    Scaling.REFERENCE_WIDTH = Scaling.windowWidth
    Scaling.REFERENCE_HEIGHT = Scaling.windowHeight
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

function Scaling.toScreen(x, y)
    local s, _ = Scaling.getScale()
    return x * s, y * s
end

function Scaling.scaleSize(size)
    if type(size) ~= 'number' then return size end
    local s, _ = Scaling.getScale()
    return size * s
end

function Scaling.scaleX(x)
    local s, _ = Scaling.getScale()
    return x * s
end

function Scaling.scaleY(y)
    local _, s = Scaling.getScale()
    return y * s
end

function Scaling.toGame(x, y)
    local s, _ = Scaling.getScale()
    return x / s, y / s
end

-- Convert screen coordinates to canvas/UI coordinates, accounting for canvas offset and scale
-- This is used for UI hit testing and mouse interactions
function Scaling.toUI(x, y)
    local s = Scaling.canvasScale or 1.0
    local offsetX = Scaling.canvasOffsetX or 0
    local offsetY = Scaling.canvasOffsetY or 0
    local uiX = (x - offsetX) / s
    local uiY = (y - offsetY) / s
    return uiX, uiY
end

-- Convert UI/reference coordinates (1920x1080) to screen coordinates, accounting for canvas offset and scale
function Scaling.toScreenCanvas(x, y)
    local s = Scaling.canvasScale or 1.0
    local offsetX = Scaling.canvasOffsetX or 0
    local offsetY = Scaling.canvasOffsetY or 0
    return x * s + offsetX, y * s + offsetY
end

-- Update cached canvas transform information used by toUI and toScreenCanvas
function Scaling.setCanvasTransform(offsetX, offsetY, scale)
    Scaling.canvasOffsetX = offsetX or 0
    Scaling.canvasOffsetY = offsetY or 0
    Scaling.canvasScale = scale or Scaling.getScale()
end

-- Convert screen coordinates to world coordinates, given camera component and position
function Scaling.toWorld(screenX, screenY, cameraComp, cameraPos)
    local uiX, uiY = Scaling.toUI(screenX, screenY)
    local camZoom = (cameraComp and cameraComp.zoom) or 1
    local worldX = uiX / camZoom + (cameraPos and cameraPos.x or 0)
    local worldY = uiY / camZoom + (cameraPos and cameraPos.y or 0)
    return worldX, worldY
end

-- Get current window resolution
function Scaling.getCurrentResolution()
    return love.graphics.getWidth(), love.graphics.getHeight()
end

-- Get current window width
function Scaling.getCurrentWidth()
    return love.graphics.getWidth()
end

-- Get current window height
function Scaling.getCurrentHeight()
    return love.graphics.getHeight()
end

return Scaling
