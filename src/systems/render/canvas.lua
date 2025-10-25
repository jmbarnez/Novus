-- Render Canvas Module - Handles canvas setup, shader effects, and final presentation

local ECS = require('src.ecs')
local CameraUtils = require('src.camera_utils')
local ShaderManager = require('src.shader_manager')
local Scaling = require('src.scaling')
local DisplayManager = require('src.display_manager')

local RenderCanvas = {}

local postProcess = {
    canvas = nil,
    width = 0,
    height = 0
}

local function getCanvasComponent()
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    if #canvasEntities == 0 then
        return nil
    end
    local canvasId = canvasEntities[1]
    return ECS.getComponent(canvasId, "Canvas")
end

local function ensureCanvasSize(canvasComp, width, height)
    if not canvasComp or not width or not height then
        return
    end
    if canvasComp.width ~= width or canvasComp.height ~= height then
        local Components = require('src/components')
        Components.resizeCanvas(canvasComp, width, height)
    end
end

local function syncCameraViewport(width, height)
    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities == 0 then
        return
    end
    local cameraId = cameraEntities[1]
    local cameraComp = ECS.getComponent(cameraId, "Camera")
    if cameraComp then
        cameraComp.width = width
        cameraComp.height = height
    end
end

local function ensurePostProcessCanvas(width, height)
    if not ShaderManager.isCelShadingEnabled() then
        return nil
    end
    if not postProcess.canvas or postProcess.width ~= width or postProcess.height ~= height then
        if postProcess.canvas then
            postProcess.canvas:release()
        end
        postProcess.canvas = love.graphics.newCanvas(width, height)
        postProcess.width = width
        postProcess.height = height
        ShaderManager.setScreenSize(width, height)
    end
    return postProcess.canvas
end

function RenderCanvas.setupCanvas()
    local canvasComp = getCanvasComponent()
    if not canvasComp or not canvasComp.canvas then
        return nil
    end

    local renderWidth, renderHeight = DisplayManager.getRenderDimensions()
    ensureCanvasSize(canvasComp, renderWidth, renderHeight)
    syncCameraViewport(renderWidth, renderHeight)

    love.graphics.push('all')
    love.graphics.setCanvas(canvasComp.canvas)
    love.graphics.origin()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha')

    return canvasComp
end

function RenderCanvas.resizeCanvas()
    local canvasComp = getCanvasComponent()
    if not canvasComp then
        return
    end

    local renderWidth, renderHeight = DisplayManager.getRenderDimensions()
    ensureCanvasSize(canvasComp, renderWidth, renderHeight)
    syncCameraViewport(renderWidth, renderHeight)
end

function RenderCanvas.finalizeCanvas(canvasComp)
    if not canvasComp or not canvasComp.canvas then
        return
    end

    -- Restore any remaining camera transforms and canvas state before drawing to screen
    CameraUtils.resetTransform()
    love.graphics.pop()

    love.graphics.push('all')
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha')

    local windowWidth, windowHeight = DisplayManager.getWindowDimensions()
    local renderWidth, renderHeight = canvasComp.width, canvasComp.height
    local scaleX = windowWidth / renderWidth
    local scaleY = windowHeight / renderHeight
    local offsetX, offsetY = 0, 0

    canvasComp.offsetX = offsetX
    canvasComp.offsetY = offsetY
    canvasComp.scaleX = scaleX
    canvasComp.scaleY = scaleY
    canvasComp.scale = math.min(scaleX, scaleY)

    Scaling.setCanvasTransform(offsetX, offsetY, scaleX, scaleY)

    if ShaderManager.isCelShadingEnabled() then
        ShaderManager.updateTime()
        local postCanvas = ensurePostProcessCanvas(windowWidth, windowHeight)
        if postCanvas then
            love.graphics.setShader(ShaderManager.getCelShader())
            love.graphics.setCanvas(postCanvas)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scaleX, scaleY)
            love.graphics.setShader()
            love.graphics.setCanvas()
            love.graphics.draw(postCanvas, 0, 0)
        end
    else
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scaleX, scaleY)
    end

    love.graphics.pop()
end

function RenderCanvas.release()
    if postProcess.canvas then
        postProcess.canvas:release()
        postProcess.canvas = nil
        postProcess.width = 0
        postProcess.height = 0
    end
end

return RenderCanvas
