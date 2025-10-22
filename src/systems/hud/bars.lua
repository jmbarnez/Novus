-- HUD Bars Module - Health bars above enemies, asteroids, and wreckage

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')

local HUDBars = {}

function HUDBars.drawEnemyHealthBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    local shipEntities = ECS.getEntitiesWith({"Hull", "Position", "Renderable"})
    
    for _, entityId in ipairs(shipEntities) do
        if ECS.hasComponent(entityId, "ControlledBy") then
            local controlled = ECS.getComponent(entityId, "ControlledBy")
            if controlled and controlled.pilotId then
                local pilot = ECS.getComponent(controlled.pilotId, "Player")
                if pilot then goto continue_ship end
            end
        end
        
        local position = ECS.getComponent(entityId, "Position")
        local hull = ECS.getComponent(entityId, "Hull")
        local shield = ECS.getComponent(entityId, "Shield")
        local renderable = ECS.getComponent(entityId, "Renderable")
        
        if position and hull and renderable and camera and cameraPos then
            local canvasX = (position.x - cameraPos.x) * camera.zoom
            local canvasY = (position.y - cameraPos.y) * camera.zoom
            
            local screenX, screenY = Scaling.toScreenCanvas(canvasX, canvasY)
            
            local barWidth = 32
            local barHeight = 5
            local x = screenX - barWidth / 2
            local y = screenY - (renderable.radius or 15) * camera.zoom - 10
            
            love.graphics.setColor(PlasmaTheme.colors.healthBarBg)
            love.graphics.rectangle("fill", x, y, barWidth, barHeight, 2, 2)
            
            local hullRatio = math.max(0, math.min(1, (hull.current or 0) / (hull.max or 1)))
            love.graphics.setColor(PlasmaTheme.colors.healthBarFill)
            love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (barWidth - 2) * hullRatio), barHeight - 2, 1, 1)
            
            if shield and shield.max > 0 then
                local sRatio = math.max(0, math.min(1, (shield.current or 0) / (shield.max or 1)))
                love.graphics.setColor(PlasmaTheme.colors.shieldBarFill)
                love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (barWidth - 2) * sRatio), barHeight - 2, 1, 1)
            end
            
            love.graphics.setColor(PlasmaTheme.colors.outlineBlack)
            love.graphics.setLineWidth(PlasmaTheme.colors.outlineThick)
            love.graphics.rectangle("line", x, y, barWidth, barHeight, 2, 2)
            love.graphics.setLineWidth(1)
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
    
    if not camera or not cameraPos then return end
    
    local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(asteroidEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if position and durability and durability.current and durability.max then
            if durability.current < durability.max then
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
                PlasmaTheme.drawDurabilityBar(x, y, barWidth, barHeight, frac, "asteroid")
            end
        end
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
    
    if not camera or not cameraPos then return end
    
    local wreckageEntities = ECS.getEntitiesWith({"Wreckage", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(wreckageEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if position and durability and durability.current and durability.max then
            if durability.current < durability.max then
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
                PlasmaTheme.drawDurabilityBar(x, y, barWidth, barHeight, frac, "wreckage")
            end
        end
    end
end

return HUDBars

