-- Render Canvas Module - Handles canvas setup, shader effects, and final rendering

local ECS = require('src.ecs')
local CameraUtils = require('src.camera_utils')
local ShaderManager = require('src.shader_manager')
local Scaling = require('src.scaling')
local DisplayManager = require('src.display_manager')

local RenderCanvas = {}

-- Background swirl shader (lazy-loaded)
local backgroundShader = nil
local function getBackgroundShader()
    if not backgroundShader then
        local shaderCode = love.filesystem.read('src/shaders/background_swirl.frag')
        if shaderCode then
            local ok, shader = pcall(love.graphics.newShader, shaderCode)
            if ok and shader then
                backgroundShader = shader
            end
        end
    end
    return backgroundShader
end

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

    -- Get camera position for parallax effect
    local cameraX, cameraY = 0, 0
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local cameraPos = ECS.getComponent(cameraId, "Position")
        if cameraPos then
            cameraX = cameraPos.x or 0
            cameraY = cameraPos.y or 0
        end
    end

    -- Try to draw colorful swirl background with shader
    local shader = getBackgroundShader()
    if shader then
        -- Set shader uniforms
        local renderW, renderH = DisplayManager.getRenderDimensions()
        shader:send('resolution', {renderW, renderH})
        shader:send('time', love.timer.getTime())
        shader:send('cameraOffset', {cameraX, cameraY})
        
        -- Draw full-screen background with shader
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)
        love.graphics.setShader()
    else
        -- Fallback to solid color if shader fails
        local WorldLoader = require('src.world_loader')
        local world = WorldLoader.getCurrentWorld and WorldLoader.getCurrentWorld()
        local backgroundColor = world and world.theme and world.theme.background or {0.1, 0.3, 0.5}
        local bc = backgroundColor or {0.1, 0.3, 0.5}
        local br, bg, bb, ba = bc[1] or 0.1, bc[2] or 0.3, bc[3] or 0.5, bc[4] or 1
        love.graphics.clear(br, bg, bb, ba)
        love.graphics.setColor(br, bg, bb, ba)
        love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)
    end
    
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

    -- Clear the screen to blue-green tint before drawing the canvas (handles letterboxing)
    love.graphics.clear(0.1, 0.25, 0.35, 1)

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
