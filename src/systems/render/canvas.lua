-- Render Canvas Module - Handles canvas setup, shader effects, and final rendering

local ECS = require('src.ecs')
local CameraUtils = require('src.camera_utils')
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

    -- Pure black space background (realistic deep space)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)

    -- no special nebula canvas here; parallax handles nebula rendering directly
    return canvasComp
end

-- Resize the main canvas to match current window resolution
function RenderCanvas.resizeCanvas()
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    if #canvasEntities == 0 then return end

    local canvasId = canvasEntities[1]
    local canvasComp = ECS.getComponent(canvasId, "Canvas")

    if canvasComp then
        local Constants = require('src.constants')
        local newWidth = Constants.getScreenWidth()
        local newHeight = Constants.getScreenHeight()

        -- Only resize if dimensions actually changed
        if canvasComp.width ~= newWidth or canvasComp.height ~= newHeight then
            local Components = require('src/components')
            Components.resizeCanvas(canvasComp, newWidth, newHeight)
        end
    end

    -- Also update camera viewport dimensions
    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local cameraComp = ECS.getComponent(cameraId, "Camera")
        if cameraComp then
            local Constants = require('src.constants')
            cameraComp.width = Constants.getScreenWidth()
            cameraComp.height = Constants.getScreenHeight()
        end
    end
end

function RenderCanvas.finalizeCanvas(canvasComp)
    CameraUtils.resetTransform()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()

    -- Clear the screen
    love.graphics.clear(0, 0, 0, 1)

    local w, h = love.graphics.getDimensions()
    
    -- Calculate scale to fill the entire window (stretch to fit)
    local scaleX = w / canvasComp.width
    local scaleY = h / canvasComp.height
    
    -- Set canvas transform to fill the window completely
    canvasComp.offsetX = 0
    canvasComp.offsetY = 0
    canvasComp.scale = 1.0
    Scaling.setCanvasTransform(0, 0, 1.0)

    -- Create or reuse post-processing canvas for shader effects
    if not _G.postProcessCanvas or _G.postProcessCanvasWidth ~= w or _G.postProcessCanvasHeight ~= h then
        -- Release old post-process canvas if it exists
        if _G.postProcessCanvas then
            _G.postProcessCanvas:release()
        end
        _G.postProcessCanvas = love.graphics.newCanvas(w, h)
        _G.postProcessCanvasWidth = w
        _G.postProcessCanvasHeight = h
        -- Only update shader screen size when dimensions actually change
        if ShaderManager.isCelShadingEnabled() then
            ShaderManager.setScreenSize(w, h)
        end
    end

    -- Apply shader effect to game canvas and render to post-process canvas
    if ShaderManager.isCelShadingEnabled() then
        -- Update shader time for animated effects (waves, pulse, etc.)
        ShaderManager.updateTime()
        -- Render main canvas through cel shader into post-process canvas
        love.graphics.setShader(ShaderManager.getCelShader())
        love.graphics.setCanvas(_G.postProcessCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.draw(canvasComp.canvas, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()

        -- Draw the processed (shaded) main canvas on top
        love.graphics.draw(_G.postProcessCanvas, 0, 0, 0, scaleX, scaleY)
    else
        -- No post-processing: just draw main canvas directly
        love.graphics.draw(canvasComp.canvas, 0, 0, 0, scaleX, scaleY)
    end
end

return RenderCanvas

