-- Render Canvas Module - Handles canvas setup, shader effects, and final rendering

local ECS = require('src.ecs')
local ShaderManager = require('src.shader_manager')
local Scaling = require('src.scaling')

local RenderCanvas = {}

function RenderCanvas.setupCanvas()
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    if #canvasEntities == 0 then return nil end
    local canvasId = canvasEntities[1]
    local canvasComp = ECS.getComponent(canvasId, "Canvas")
    if not canvasComp or not canvasComp.canvas or not canvasComp.width or not canvasComp.height then return nil end

    love.graphics.setCanvas(canvasComp.canvas)
    love.graphics.clear()

    love.graphics.setColor(0.01, 0.01, 0.015, 1)
    love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)
    
    return canvasComp
end

function RenderCanvas.finalizeCanvas(canvasComp)
    local CameraSystem = ECS.getSystem("CameraSystem")
    if CameraSystem and CameraSystem.resetTransform then
        CameraSystem.resetTransform()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()
    
    local w, h = love.graphics.getDimensions()
    local scaleX = w / canvasComp.width
    local scaleY = h / canvasComp.height
    local scale = math.min(scaleX, scaleY)
    local offsetX = (w - canvasComp.width * scale) / 2
    local offsetY = (h - canvasComp.height * scale) / 2

    if not _G.canvasDebugPrinted then
        print(string.format("Canvas: %dx%d, Screen: %dx%d, Scale: %.3f",
            canvasComp.width, canvasComp.height, w, h, scale))
        _G.canvasDebugPrinted = true
    end
    
    canvasComp.offsetX = offsetX
    canvasComp.offsetY = offsetY
    canvasComp.scale = scale
    Scaling.setCanvasTransform(offsetX, offsetY, scale)

    -- Create or reuse post-processing canvas for shader effects
    if not _G.postProcessCanvas or _G.postProcessCanvasWidth ~= w or _G.postProcessCanvasHeight ~= h then
        _G.postProcessCanvas = love.graphics.newCanvas(w, h)
        _G.postProcessCanvasWidth = w
        _G.postProcessCanvasHeight = h
    end
    
    -- Apply shader effect to game canvas and render to post-process canvas
    if ShaderManager.isCelShadingEnabled() then
        ShaderManager.setScreenSize(w, h)
        love.graphics.setShader(ShaderManager.getCelShader())
        love.graphics.setCanvas(_G.postProcessCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
        love.graphics.setShader()
        love.graphics.setCanvas()
        love.graphics.draw(_G.postProcessCanvas, 0, 0)
    else
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
    end
end

return RenderCanvas

