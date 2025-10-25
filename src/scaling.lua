---@diagnostic disable: undefined-global
-- scaling.lua - universal scaling utilities for game/UI rendering

local Scaling = {}

Scaling.REFERENCE_WIDTH = 1920
Scaling.REFERENCE_HEIGHT = 1080

-- Aspect control: default to stretching to match the window (no letterboxing)
Scaling.maintainAspect = false
Scaling.fillWider = false

local function getWindowSize()
    if love and love.graphics and love.graphics.getWidth and love.graphics.getHeight then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        if (w or 0) > 0 and (h or 0) > 0 then
            return w, h
        end
    end
    return Scaling.REFERENCE_WIDTH, Scaling.REFERENCE_HEIGHT
end

local function computeScale(windowSize, referenceSize)
    if not referenceSize or referenceSize == 0 then
        return 1
    end
    windowSize = windowSize or referenceSize
    return windowSize / referenceSize
end

local function refreshDerived()
    Scaling._scaleX = computeScale(Scaling.windowWidth, Scaling.REFERENCE_WIDTH)
    Scaling._scaleY = computeScale(Scaling.windowHeight, Scaling.REFERENCE_HEIGHT)
    Scaling._uniformScale = math.min(Scaling._scaleX, Scaling._scaleY)

    Scaling._effectiveScaleX = Scaling._scaleX
    Scaling._effectiveScaleY = Scaling._scaleY
    Scaling._offsetX = 0
    Scaling._offsetY = 0

    Scaling.canvasScaleX = 1
    Scaling.canvasScaleY = 1
    Scaling.canvasOffsetX = 0
    Scaling.canvasOffsetY = 0
    Scaling.canvasScale = 1
end

Scaling.windowWidth, Scaling.windowHeight = getWindowSize()
refreshDerived()

function Scaling.update()
    Scaling.windowWidth, Scaling.windowHeight = getWindowSize()
    refreshDerived()
end

function Scaling.getScale()
    return Scaling._uniformScale
end

function Scaling.toScreen(x, y)
    return Scaling.scaleX(x), Scaling.scaleY(y)
end

function Scaling.scaleSize(size)
    if type(size) ~= "number" then return size end
    return size * Scaling._uniformScale
end

function Scaling.scaleX(x)
    if type(x) ~= "number" then return x end
    return x * Scaling._effectiveScaleX
end

function Scaling.scaleY(y)
    if type(y) ~= "number" then return y end
    return y * Scaling._effectiveScaleY
end

function Scaling.toGame(x, y)
    local ox = Scaling.canvasOffsetX or 0
    local oy = Scaling.canvasOffsetY or 0
    local sx = Scaling.canvasScaleX or Scaling._effectiveScaleX
    local sy = Scaling.canvasScaleY or Scaling._effectiveScaleY
    return (x - ox) / sx, (y - oy) / sy
end

-- Convert screen coordinates to canvas/UI coordinates, accounting for canvas offset and scale.
function Scaling.toUI(x, y)
    local sX = Scaling.canvasScaleX or Scaling._effectiveScaleX
    local sY = Scaling.canvasScaleY or Scaling._effectiveScaleY
    local offsetX = Scaling.canvasOffsetX or 0
    local offsetY = Scaling.canvasOffsetY or 0
    local uiX = (x - offsetX) / sX
    local uiY = (y - offsetY) / sY
    return uiX, uiY
end

-- Convert UI/reference coordinates (1920x1080) to screen coordinates, accounting for canvas offset and scale.
function Scaling.toScreenCanvas(x, y)
    local sX = Scaling.canvasScaleX or Scaling._effectiveScaleX
    local sY = Scaling.canvasScaleY or Scaling._effectiveScaleY
    local offsetX = Scaling.canvasOffsetX or 0
    local offsetY = Scaling.canvasOffsetY or 0
    return x * sX + offsetX, y * sY + offsetY
end

-- Update cached canvas transform information used by toUI and toScreenCanvas.
function Scaling.setCanvasTransform(offsetX, offsetY, scaleX, scaleY)
    Scaling.canvasOffsetX = offsetX or 0
    Scaling.canvasOffsetY = offsetY or 0

    if scaleY == nil then
        local scaleValue = scaleX or Scaling._uniformScale
        Scaling.canvasScaleX = scaleValue
        Scaling.canvasScaleY = scaleValue
    else
        Scaling.canvasScaleX = scaleX or Scaling._effectiveScaleX
        Scaling.canvasScaleY = scaleY
    end

    Scaling.canvasScale = math.min(Scaling.canvasScaleX, Scaling.canvasScaleY)
end

-- Convert screen coordinates to world coordinates, given camera component and position.
function Scaling.toWorld(screenX, screenY, cameraComp, cameraPos)
    local uiX, uiY = Scaling.toUI(screenX, screenY)
    local camZoom = (cameraComp and cameraComp.zoom) or 1
    local worldX = uiX / camZoom + (cameraPos and cameraPos.x or 0)
    local worldY = uiY / camZoom + (cameraPos and cameraPos.y or 0)
    return worldX, worldY
end

function Scaling.getCurrentResolution()
    return love.graphics.getWidth(), love.graphics.getHeight()
end

function Scaling.getCurrentWidth()
    return love.graphics.getWidth()
end

function Scaling.getCurrentHeight()
    return love.graphics.getHeight()
end

return Scaling
