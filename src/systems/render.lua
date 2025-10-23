---@diagnostic disable: undefined-global
-- Render System - Coordinates all rendering subsystems
-- Delegates to specialized render modules for different types of rendering

local ECS = require('src.ecs')
local Parallax = require('src.parallax')
local RenderEntities = require('src.systems.render.entities')
local RenderTurrets = require('src.systems.render.turrets')
local RenderEffects = require('src.systems.render.effects')
local RenderCanvas = require('src.systems.render.canvas')

local RenderSystem = {
    name = "RenderSystem",

    draw = function()
        local Profiler = require('src.profiler')
        Profiler.start("canvas_setup")

        -- Initialize rendering counters
        culledItems = 0
        renderedItems = 0
        local culledEntities = 0
        local renderedEntities = 0

        -- Setup canvas
        local canvasComp = RenderCanvas.setupCanvas()
        if not canvasComp then return end

        Profiler.stop("canvas_setup")
        Profiler.start("background_draw")

    -- Nebula clouds removed (simpler background) -- previously drawn here

        -- Draw starfield background
        local starFieldEntities = ECS.getEntitiesWith({"StarField"})
        for _, entityId in ipairs(starFieldEntities) do
            local starFieldComp = ECS.getComponent(entityId, "StarField")
            if starFieldComp then
                local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
                if #cameraEntities > 0 then
                    local cameraId = cameraEntities[1]
                    local cameraPos = ECS.getComponent(cameraId, "Position")
                    if cameraPos then
                        Parallax.draw(starFieldComp, cameraPos.x, cameraPos.y, canvasComp.width, canvasComp.height)
                    end
                end
            end
        end

        Profiler.stop("background_draw")
        Profiler.start("camera_transform")

        local CameraSystem = ECS.getSystem("CameraSystem")
        if CameraSystem and CameraSystem.applyTransform then
            CameraSystem.applyTransform()
        end

        Profiler.stop("camera_transform")
        Profiler.start("entity_rendering")

        -- Draw trails and debris first
        RenderEffects.drawTrails()
        RenderEffects.drawDebris()

        -- Get camera for culling calculations
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local cullingCamera = nil
        local cullingCameraPos = nil
        if #cameraEntities > 0 then
            cullingCamera = ECS.getComponent(cameraEntities[1], "Camera")
            cullingCameraPos = ECS.getComponent(cameraEntities[1], "Position")
        end

        -- Draw entities (items, ships, asteroids, etc.)
        renderedItems, culledItems = RenderEntities.drawItems(cullingCameraPos, cullingCamera)

        -- Draw turrets for ships
        local renderableEntities = ECS.getEntitiesWith({"Position", "Renderable", "PolygonShape"})
        for _, entityId in ipairs(renderableEntities) do
            local position = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable")
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            
            if position and renderable and polygonShape and renderable.shape == "polygon" then
                local controlledBy = ECS.getComponent(entityId, "ControlledBy")
                local isPlayerDrone = false
                if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player") then
                    isPlayerDrone = true
                end
                local isShip = ECS.hasComponent(entityId, "Hull")
                
                if isPlayerDrone then
                    RenderTurrets.drawPlayerTurret(entityId, position, polygonShape, renderable)
                elseif isShip then
                    RenderTurrets.drawEnemyTurret(entityId, position, polygonShape, renderable)
                end
            end
        end

        -- Draw shield impact effects
        local ShieldImpactSystem = ECS.getSystem("ShieldImpactSystem")
        if ShieldImpactSystem and ShieldImpactSystem.draw then
            ShieldImpactSystem.draw()
        end

        -- Draw effects
        RenderEffects.drawLasers()
        RenderEffects.drawHotspots()
        RenderEffects.drawMagneticField()
        RenderEffects.drawTargetingIndicator()

        -- Draw target HUD indicator circle (in world space)
        local TargetHUD = require('src.systems.target_hud')
        TargetHUD.drawWorldIndicator()

        -- Record culling statistics to profiler
        Profiler.recordCulling(renderedItems + renderedEntities, culledItems + culledEntities)

        Profiler.stop("entity_rendering")
        Profiler.start("canvas_finalize")

        -- Finalize canvas (apply shaders, draw to screen)
        RenderCanvas.finalizeCanvas(canvasComp)
        
        Profiler.stop("canvas_finalize")
        Profiler.start("ui_overlay")

        -- Reset graphics state before drawing UI
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("alpha")
        
        -- Draw enemy health bars FIRST so they render behind UI windows
        local HUDBars = require('src.systems.hud.bars')
        local w, h = love.graphics.getDimensions()
        HUDBars.drawEnemyHealthBars(w, h)
        HUDBars.drawAsteroidDurabilityBars(w, h)
        HUDBars.drawWreckageDurabilityBars(w, h)
        
        -- Draw UI windows (notifications, dialogs, windows)
        local UISystem = ECS.getSystem("UISystem")
        if UISystem and UISystem.draw then
            UISystem.draw(canvasComp.width, canvasComp.height)
        end

        -- Draw HUD overlays in screen space (without enemy health bars)
        local HUDSystem = ECS.getSystem("HUDSystem")
        if HUDSystem and HUDSystem.draw then
            HUDSystem.draw(w, h)
        end

        Profiler.stop("ui_overlay")
    end
}

return RenderSystem
