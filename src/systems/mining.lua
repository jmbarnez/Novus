-- Mining System - Handles the player's mining laser

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')

local MiningSystem = {
    name = "MiningSystem",
    laserEntity = nil
}

local LASER_DPS = 50 -- Damage per second

function MiningSystem.update(dt)
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Position"})
    if #playerEntities == 0 then return end
    local playerId = playerEntities[1]
    local playerPos = ECS.getComponent(playerId, "Position")

    if love.mouse.isDown(1) then -- Left mouse button
        if not MiningSystem.laserEntity then
            -- Create a new laser entity
            MiningSystem.laserEntity = ECS.createEntity()
            ECS.addComponent(MiningSystem.laserEntity, "LaserBeam", Components.LaserBeam({}))
        end

        -- Update the laser's position
        local laser = ECS.getComponent(MiningSystem.laserEntity, "LaserBeam")
        local mouseX, mouseY = love.mouse.getPosition()

        -- Convert mouse position to world coordinates
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
        local cameraPos = ECS.getComponent(cameraEntities[1], "Position")

        -- Apply inverse canvas and camera transforms
        mouseX = (mouseX / cameraComp.zoom - canvasComp.offsetX) / canvasComp.scale + cameraPos.x
        mouseY = (mouseY / cameraComp.zoom - canvasComp.offsetY) / canvasComp.scale + cameraPos.y

        -- Calculate angle between drone and mouse
        local angle = math.atan2(mouseY - playerPos.y, mouseX - playerPos.x)

        -- Calculate muzzle position
        local muzzleOffset = 10 -- The length of the turret
        local muzzleX = playerPos.x + math.cos(angle) * muzzleOffset
        local muzzleY = playerPos.y + math.sin(angle) * muzzleOffset

        laser.start = {x = muzzleX, y = muzzleY}

        -- Raycast to find the closest intersection point
        local closestIntersection = nil
        local closestDistSq = math.huge

        local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Collidable", "Position", "PolygonShape", "Durability"})
        for _, asteroidId in ipairs(asteroidEntities) do
            local intersection = CollisionSystem.linePolygonIntersect(laser.start.x, laser.start.y, mouseX, mouseY, asteroidId)
            if intersection then
                local distSq = (intersection.x - laser.start.x)^2 + (intersection.y - laser.start.y)^2
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestIntersection = intersection
                    
                    -- Apply damage
                    local durability = ECS.getComponent(asteroidId, "Durability")
                    if durability then
                        durability.current = durability.current - LASER_DPS * dt
                    end
                    -- Store the color of the hit asteroid
                    local renderable = ECS.getComponent(asteroidId, "Renderable")
                    closestIntersection.color = renderable and renderable.color or {0.6, 0.4, 0.2, 1} -- Default to asteroid brown
                end
            end
        end

        if closestIntersection then
            laser.endPos = {x = closestIntersection.x, y = closestIntersection.y}
            -- Create impact effect
            local DebrisSystem = require('src.systems.debris')
            DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, closestIntersection.color) -- Pass color, reduce particles
        else
            laser.endPos = {x = mouseX, y = mouseY}
        end

    elseif MiningSystem.laserEntity then
        -- Destroy the laser entity when the mouse button is released
        ECS.destroyEntity(MiningSystem.laserEntity)
        MiningSystem.laserEntity = nil
    end
end

return MiningSystem
