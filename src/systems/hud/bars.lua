---@diagnostic disable: undefined-global
-- HUD Bars Module - Health bars above enemies, asteroids, and wreckage
-- Uses batched rendering for performance

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDBars = {}

-- Camera culling bounds cache
local lastCameraUpdate = 0
local cameraViewBounds = {minX = 0, maxX = 0, minY = 0, maxY = 0}
local CAMERA_MARGIN = 200  -- Extra margin for bars outside viewport

-- Update camera bounds for culling
local function updateCameraBounds(camera, cameraPos)
    if not camera or not cameraPos then return false end
    local viewWidth = (love.graphics.getWidth() / camera.zoom)
    local viewHeight = (love.graphics.getHeight() / camera.zoom)
    cameraViewBounds.minX = cameraPos.x - viewWidth / 2 - CAMERA_MARGIN
    cameraViewBounds.maxX = cameraPos.x + viewWidth / 2 + CAMERA_MARGIN
    cameraViewBounds.minY = cameraPos.y - viewHeight / 2 - CAMERA_MARGIN
    cameraViewBounds.maxY = cameraPos.y + viewHeight / 2 + CAMERA_MARGIN
    return true
end

-- Check if entity is in view
local function isInView(x, y)
    return x >= cameraViewBounds.minX and x <= cameraViewBounds.maxX and
           y >= cameraViewBounds.minY and y <= cameraViewBounds.maxY
end

function HUDBars.drawEnemyHealthBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not updateCameraBounds(camera, cameraPos) then return end
    
    local shipEntities = ECS.getEntitiesWith({"Hull", "Position", "Renderable"})
    
    -- Extract colors for batching
    local bgColor = PlasmaTheme.colors.healthBarBg
    local hullColor = PlasmaTheme.colors.healthBarFill
    local shieldColor = PlasmaTheme.colors.shieldBarFill
    local outlineColor = PlasmaTheme.colors.outlineBlack
    local outlineWidth = PlasmaTheme.colors.outlineThick
    
    for _, entityId in ipairs(shipEntities) do
        -- Skip player drone
        if ECS.hasComponent(entityId, "ControlledBy") then
            local controlled = ECS.getComponent(entityId, "ControlledBy")
            if controlled and controlled.pilotId and ECS.hasComponent(controlled.pilotId, "Player") then
                goto continue_ship
            end
        end
        
        local position = ECS.getComponent(entityId, "Position")
        local hull = ECS.getComponent(entityId, "Hull")
        local shield = ECS.getComponent(entityId, "Shield")
        local renderable = ECS.getComponent(entityId, "Renderable")
        
        if position and hull and renderable then
            -- Early culling check
            if not isInView(position.x, position.y) then
                goto continue_ship
            end
            
            local canvasX = (position.x - cameraPos.x) * camera.zoom
            local canvasY = (position.y - cameraPos.y) * camera.zoom
            
            local screenX, screenY = Scaling.toScreenCanvas(canvasX, canvasY)
            
            local barWidth = 32
            local barHeight = 5
            local x = screenX - barWidth / 2
            local y = screenY - (renderable.radius or 15) * camera.zoom - 10
            
            -- Background
            BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 2)
            
            -- Hull fill
            local hullRatio = math.max(0, math.min(1, (hull.current or 0) / (hull.max or 1)))
            local fillWidth = math.max(0, (barWidth - 2) * hullRatio)
            if fillWidth > 0 then
                BatchRenderer.queueRect(x + 1, y + 1, fillWidth, barHeight - 2, hullColor[1], hullColor[2], hullColor[3], hullColor[4], 1)
            end
            
            -- Shield overlay (if present)
            if shield and shield.max > 0 then
                local sRatio = math.max(0, math.min(1, (shield.current or 0) / (shield.max or 1)))
                local shieldWidth = math.max(0, (barWidth - 2) * sRatio)
                if shieldWidth > 0 then
                    BatchRenderer.queueRect(x + 1, y + 1, shieldWidth, barHeight - 2, shieldColor[1], shieldColor[2], shieldColor[3], shieldColor[4], 1)
                end
            end
            
            -- Outline
            BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], outlineWidth, 2)
        end
        
        ::continue_ship::
    end
end

function HUDBars.drawAsteroidDurabilityBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not updateCameraBounds(camera, cameraPos) then return end
    
    local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(asteroidEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if position and durability and durability.current and durability.max then
            -- Only show damaged bars
            if durability.current < durability.max then
                -- Early culling check
                if not isInView(position.x, position.y) then
                    goto continue_asteroid
                end
                
                local canvasX = (position.x - cameraPos.x) * camera.zoom
                local canvasY = (position.y - cameraPos.y) * camera.zoom
                
                local screenX, screenY = Scaling.toScreenCanvas(canvasX, canvasY)
                
                local barWidth = 24
                local barHeight = 3
                local radius = coll and coll.radius or 12
                local pad = radius + 6
                local x = screenX - barWidth / 2
                local y = screenY - pad * camera.zoom - 5
                
                local frac = math.max(0, math.min(1, durability.current / durability.max))
                
                -- Draw batched durability bar for asteroid
                local bgColor = PlasmaTheme.colors.healthBarBg
                local fillColor = PlasmaTheme.colors.asteroidBarFill
                local outlineColor = PlasmaTheme.colors.outlineBlack
                
                BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 1)
                local fillWidth = math.max(0, (barWidth - 2) * frac)
                if fillWidth > 0 then
                    BatchRenderer.queueRect(x + 1, y + 1, fillWidth, barHeight - 2, fillColor[1], fillColor[2], fillColor[3], fillColor[4], 0)
                end
                BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], 2, 1)
            end
        end
        ::continue_asteroid::
    end
end

function HUDBars.drawWreckageDurabilityBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not updateCameraBounds(camera, cameraPos) then return end
    
    local wreckageEntities = ECS.getEntitiesWith({"Wreckage", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(wreckageEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if position and durability and durability.current and durability.max then
            -- Only show damaged bars
            if durability.current < durability.max then
                -- Early culling check
                if not isInView(position.x, position.y) then
                    goto continue_wreckage
                end
                
                local canvasX = (position.x - cameraPos.x) * camera.zoom
                local canvasY = (position.y - cameraPos.y) * camera.zoom
                
                local screenX, screenY = Scaling.toScreenCanvas(canvasX, canvasY)
                
                local barWidth = 24
                local barHeight = 3
                local radius = coll and coll.radius or 12
                local pad = radius + 6
                local x = screenX - barWidth / 2
                local y = screenY - pad * camera.zoom - 5
                
                local frac = math.max(0, math.min(1, durability.current / durability.max))
                
                -- Draw batched durability bar for wreckage
                local bgColor = PlasmaTheme.colors.healthBarBg
                local fillColor = PlasmaTheme.colors.wreckageBarFill
                local outlineColor = PlasmaTheme.colors.outlineBlack
                
                BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 1)
                local fillWidth = math.max(0, (barWidth - 2) * frac)
                if fillWidth > 0 then
                    BatchRenderer.queueRect(x + 1, y + 1, fillWidth, barHeight - 2, fillColor[1], fillColor[2], fillColor[3], fillColor[4], 0)
                end
                BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], 2, 1)
            end
        end
        ::continue_wreckage::
    end
end

return HUDBars

