---@diagnostic disable: undefined-global
-- Render System - Coordinates all rendering subsystems
-- Delegates to specialized render modules for different types of rendering

local Constants = require('src.constants')
local ECS = require('src.ecs')
local Parallax = require('src.parallax')
local CameraUtils = require('src.camera_utils')
local RenderEntities = require('src.systems.render.entities')
local RenderTurrets = require('src.systems.render.turrets')
local RenderEffects = require('src.systems.render.effects')
local RenderCanvas = require('src.systems.render.canvas')
local DisplayManager = require('src.display_manager')
local Scaling = require('src.scaling')

-- Lazy-load subsystems to avoid circular dependencies
local ShieldImpactSystem
local WorldTooltipsSystem
local UISystem
local HUDSystem

local function getShieldImpactSystem()
    if not ShieldImpactSystem then
        ShieldImpactSystem = require('src.systems.shield_impact')
    end
    return ShieldImpactSystem
end

local function getWorldTooltipsSystem()
    if not WorldTooltipsSystem then
        WorldTooltipsSystem = require('src.systems.world_tooltips')
    end
    return WorldTooltipsSystem
end

local function getUISystem()
    if not UISystem then
        -- Get from Systems table to ensure same instance for input handling
        local Systems = require('src.systems')
        UISystem = Systems.UISystem
    end
    return UISystem
end

local function getHUDSystem()
    if not HUDSystem then
        -- Get from Systems table to ensure same instance for input handling
        local Systems = require('src.systems')
        HUDSystem = Systems.HUDSystem
    end
    return HUDSystem
end

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

        CameraUtils.applyTransform()

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
        local shieldImpact = getShieldImpactSystem()
        if shieldImpact and shieldImpact.draw then
            shieldImpact.draw()
        end

        -- Draw effects
        RenderEffects.drawLasers()
        RenderEffects.drawHotspots()
        RenderEffects.drawMagneticField()
        RenderEffects.drawTargetingIndicator()

        -- Draw target HUD indicator circle (in world space)
        local TargetHUD = require('src.systems.target_hud')
        TargetHUD.drawWorldIndicator()
        
        -- Draw world tooltips (warp gates, etc.)
        local worldTooltips = getWorldTooltipsSystem()
        if worldTooltips and worldTooltips.draw then
            worldTooltips.draw()
        end

        -- Record culling statistics to profiler
        Profiler.recordCulling(renderedItems + renderedEntities, culledItems + culledEntities)

        Profiler.stop("entity_rendering")

        -- UI OVERLAY - Draw all UI and HUD elements into the main canvas before it's finalized
        Profiler.start("ui_overlay")

        -- Reset camera transform before drawing screen-space UI
        CameraUtils.resetTransform()

        -- Update canvas transform for HUD elements before drawing them
        local windowW, windowH = DisplayManager.getWindowSize()
        local scaleX, scaleY, offsetX, offsetY = DisplayManager.computeDrawParameters(canvasComp.width, canvasComp.height)
        Scaling.setCanvasTransform(offsetX, offsetY, scaleX, scaleY)

        -- Reset graphics state before drawing UI
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("alpha")

        -- Begin batching for all UI/HUD elements
        local BatchRenderer = require('src.ui.batch_renderer')
        BatchRenderer.begin()

        -- Draw durability bars for asteroids and wreckages (world-space UI)
        -- These render FIRST (behind UI windows) to ensure UI appears on top
        Profiler.start("ui_durability_bars")
        local EnemyBars = require('src.systems.hud.enemy_bars')
        local AsteroidBars = require('src.systems.hud.asteroid_bars')
        local WreckageBars = require('src.systems.hud.wreckage_bars')
        local w, h = love.graphics.getDimensions()
        EnemyBars.draw(w, h)
        AsteroidBars.draw(w, h)
        WreckageBars.draw(w, h)
        Profiler.stop("ui_durability_bars")

        -- Draw HUD overlays in screen space (queued to batch)
        Profiler.start("ui_hud_overlays")
        local hud = getHUDSystem()
        if hud and hud.draw then
            hud.draw(screenWidth, screenHeight) -- Pass display resolution
        end
        Profiler.stop("ui_hud_overlays")

        -- Flush batched HUD elements before drawing UI windows
        Profiler.start("ui_hud_flush")
        BatchRenderer.flush()
        Profiler.stop("ui_hud_flush")

        -- Draw UI windows LAST (notifications, dialogs, windows) - these use immediate mode
        -- This ensures UI windows render ON TOP of all HUD elements
        Profiler.start("ui_windows")
        local ui = getUISystem()
        if ui and ui.draw then
            local screenWidth, screenHeight = Constants.getScreenWidth(), Constants.getScreenHeight()
            ui.draw(screenWidth, screenHeight) -- Pass display resolution
        end
        Profiler.stop("ui_windows")

        -- Draw the death overlay, if visible (immediate mode, always on top)
        Profiler.start("ui_death_overlay")
        local DeathOverlay = require('src.ui.death_overlay')
        DeathOverlay.draw()
        Profiler.stop("ui_death_overlay")

        Profiler.stop("ui_overlay")

        Profiler.start("canvas_finalize")

        -- Finalize canvas (apply shaders, draw to screen)
        RenderCanvas.finalizeCanvas(canvasComp)
        
        Profiler.stop("canvas_finalize")
    end
}

return RenderSystem
