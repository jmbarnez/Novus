-- Render Canvas Module - Handles canvas setup, shader effects, and final rendering

local ECS = require('src.ecs')
local CameraUtils = require('src.camera_utils')
local ShaderManager = require('src.shader_manager')
local Scaling = require('src.scaling')
local DisplayManager = require('src.display_manager')

local RenderCanvas = {}

local function ensureCanvasComponent()
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    if #canvasEntities == 0 then return nil end
    local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
    if not canvasComp then return nil end

    local renderW, renderH = DisplayManager.getRenderDimensions()
    if not canvasComp.canvas or canvasComp.width ~= renderW or canvasComp.height ~= renderH then
        local Components = require('src.components')
        Components.resizeCanvas(canvasComp, renderW, renderH)
    end

    return canvasComp
end

function RenderCanvas.setupCanvas()
    local canvasComp = ensureCanvasComponent()
    if not canvasComp or not canvasComp.canvas then return nil end

    love.graphics.setCanvas(canvasComp.canvas)

    -- Get current world background color (default to navy blue if no world)
    local WorldLoader = require('src.world_loader')
    local world = WorldLoader.getCurrentWorld and WorldLoader.getCurrentWorld()
    -- Nearly black, but with a hint of blue for space
    local backgroundColor = world and world.theme and world.theme.background or {0.04, 0.06, 0.10}

    love.graphics.clear(unpack(backgroundColor))

    -- Fill background with world-specific space color to avoid residual artifacts
    love.graphics.setColor(unpack(backgroundColor))
    love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)
    love.graphics.setColor(1, 1, 1, 1)

    return canvasComp
end

function RenderCanvas.resizeCanvas()
    local canvasComp = ensureCanvasComponent()
    if not canvasComp then return end

    -- Update camera viewport dimensions to match render resolution
    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
        if cameraComp then
            local renderW, renderH = DisplayManager.getRenderDimensions()
            cameraComp.width = renderW
            cameraComp.height = renderH
        end
    end
end

function RenderCanvas.setRenderResolution(newWidth, newHeight)
    if not DisplayManager.setRenderResolution(newWidth, newHeight) then
        return
    end
    RenderCanvas.resizeCanvas()
end

function RenderCanvas.onResize(screenW, screenH)
    -- Update canvas dimensions when screen resolution changes
    RenderCanvas.resizeCanvas()
end

function RenderCanvas.finalizeCanvas(canvasComp)
    if not canvasComp or not canvasComp.canvas then return end

    CameraUtils.resetTransform()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()

    -- Clear the screen to nearly black (very dark blue) before drawing the canvas (handles letterboxing)
    love.graphics.clear(0.04, 0.06, 0.10, 1)

    local windowW, windowH = DisplayManager.getWindowSize()
    local scaleX, scaleY, offsetX, offsetY = DisplayManager.computeDrawParameters(canvasComp.width, canvasComp.height)

    canvasComp.offsetX = offsetX
    canvasComp.offsetY = offsetY
    canvasComp.scaleX = scaleX
    canvasComp.scaleY = scaleY
    canvasComp.scale = math.min(scaleX, scaleY)

    Scaling.setCanvasTransform(offsetX, offsetY, scaleX, scaleY)

    -- Apply optional shader effects using a post-process canvas sized to the window
    if ShaderManager.isCelShadingEnabled() then
        ShaderManager.updateTime()
        ShaderManager.setScreenSize(windowW, windowH)

        local postCanvas = DisplayManager.getPostProcessCanvas(windowW, windowH)
        love.graphics.setCanvas(postCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(ShaderManager.getCelShader())
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scaleX, scaleY)
        love.graphics.setShader()
        love.graphics.setCanvas()

        love.graphics.draw(postCanvas, 0, 0)
    else
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scaleX, scaleY)
    end
end

return RenderCanvas
