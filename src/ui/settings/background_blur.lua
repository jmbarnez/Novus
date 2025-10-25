---@diagnostic disable: undefined-global
-- ============================================================================
-- Background Blur Handler
-- ============================================================================
-- Handles the blur effect background for settings window

local Constants = require('src.constants')

local BackgroundBlur = {}

function BackgroundBlur:new()
    local blur = {
        _blurCanvas = nil,
        _screenW = nil,
        _screenH = nil,
        _blurW = nil,
        _blurH = nil
    }
    setmetatable(blur, self)
    self.__index = self
    return blur
end

-- Capture background for blur effect
function BackgroundBlur:captureBackground()
    local w, h = Constants.getScreenWidth(), Constants.getScreenHeight()
    -- Create a small canvas to draw a downscaled scene into (for cheap blur)
    local downW = math.max(160, math.floor(w / 8))
    local downH = math.max(90, math.floor(h / 8))
    
    -- Reuse existing canvas if dimensions haven't changed
    if not self._blurCanvas or self._blurW ~= downW or self._blurH ~= downH then
        -- Release old canvas if it exists
        if self._blurCanvas then
            self._blurCanvas:release()
        end
        self._blurCanvas = love.graphics.newCanvas(downW, downH)
        self._blurW = downW
        self._blurH = downH
    end
    
    self._screenW = w
    self._screenH = h
    
    -- Copy the game's main canvas into the small canvas scaled down
    local ECS = require('src.ecs')
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    if #canvasEntities > 0 then
        local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
        if canvasComp and canvasComp.canvas then
            love.graphics.push()
            love.graphics.origin()
            love.graphics.setCanvas(self._blurCanvas)
            love.graphics.clear()
            love.graphics.origin()
            -- Draw the main canvas scaled down into the small canvas
            love.graphics.setShader()
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(canvasComp.canvas, 0, 0, 0, downW / canvasComp.width, downH / canvasComp.height)
            love.graphics.setCanvas()
            love.graphics.pop()
        end
    end
end

-- Draw blurred background
function BackgroundBlur:draw(alpha)
    if not self._blurCanvas then return end
    
    love.graphics.push()
    -- Ensure smooth scaling
    self._blurCanvas:setFilter('linear', 'linear')
    local cw, ch = self._blurCanvas:getWidth(), self._blurCanvas:getHeight()
    local sw, sh = love.graphics.getDimensions()
    local sx = sw / cw
    local sy = sh / ch
    -- Draw the downscaled canvas stretched up once
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1 * alpha)
    love.graphics.draw(self._blurCanvas, 0, 0, 0, sx, sy)
    -- Overlay a subtle dark tint to maintain readability
    love.graphics.setColor(0, 0, 0, 0.35 * alpha)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    love.graphics.pop()
end

-- Draw fallback background (semi-transparent overlay)
function BackgroundBlur:drawFallback(alpha)
    love.graphics.setColor(0, 0, 0, 0.3 * alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end

-- Clean up resources
function BackgroundBlur:cleanup()
    if self._blurCanvas then
        self._blurCanvas:release()
        self._blurCanvas = nil
    end
end

return BackgroundBlur
