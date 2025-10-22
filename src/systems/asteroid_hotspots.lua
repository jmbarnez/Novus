-- Asteroid Hotspots System
-- Manages temporary weak points on asteroids that give mining bonuses

local ECS = require('src.ecs')
local Components = require('src.components')
local Procedural = require('src.procedural')

local HotspotSystem = {
    name = "AsteroidHotspotSystem",
    priority = 21
}

-- Check if an asteroid already has a hotspot
local function asteroidHasHotspot(asteroidId)
    local attachedEntities = ECS.getEntitiesWith({"Attached", "Hotspot"})
    for _, id in ipairs(attachedEntities) do
        local attached = ECS.getComponent(id, "Attached")
        if attached and attached.parentId == asteroidId then
            return true
        end
    end
    return false
end

-- Create a hotspot on an asteroid
local function createHotspot(asteroidId)
    -- Check if asteroid already has a hotspot
    if asteroidHasHotspot(asteroidId) then
        return
    end
    
    local asteroidPos = ECS.getComponent(asteroidId, "Position")
    local asteroidPoly = ECS.getComponent(asteroidId, "PolygonShape")
    if not asteroidPos or not asteroidPoly or not asteroidPoly.vertices then
        return
    end
    
    -- Pick a random vertex from the asteroid polygon
    local vertices = asteroidPoly.vertices
    if #vertices == 0 then return end
    
    local v = vertices[math.random(#vertices)]
    
    -- Random lifetime between 8-12 seconds
    local lifetime = 8 + math.random() * 4
    
    -- Random DPS multiplier between 1.5x and 2.5x
    local dpsMultiplier = 1.5 + math.random() * 1.0
    
    -- Create hotspot entity
    local hotspotId = ECS.createEntity()
    ECS.addComponent(hotspotId, "Position", Components.Position(asteroidPos.x + v.x, asteroidPos.y + v.y))
    ECS.addComponent(hotspotId, "Collidable", Components.Collidable(8))
    ECS.addComponent(hotspotId, "Hotspot", Components.Hotspot(lifetime, dpsMultiplier))
    
    -- Add small polygon shape for collision detection
    local hotspotVerts = Procedural.generatePolygonVertices(6, 8)
    ECS.addComponent(hotspotId, "PolygonShape", Components.PolygonShape(hotspotVerts, 0))
    ECS.addComponent(hotspotId, "Attached", Components.Attached(asteroidId, v.x, v.y))
end

-- Randomly spawn hotspots on asteroids that are being mined
local function spawnRandomHotspots()
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "PolygonShape", "BeingMined"})
    
    -- Spawn a hotspot on 15% of asteroids being mined that don't already have one
    for _, asteroidId in ipairs(asteroids) do
        if math.random() < 0.15 then
            createHotspot(asteroidId)
        end
    end
end

-- Update hotspots: move with parent, decrement timer, cleanup expired
function HotspotSystem.update(dt)
    local currentTime = love.timer.getTime()
    
    -- Clean up BeingMined components from asteroids that haven't been hit recently
    local beingMinedEntities = ECS.getEntitiesWith({"BeingMined"})
    for _, asteroidId in ipairs(beingMinedEntities) do
        local beingMined = ECS.getComponent(asteroidId, "BeingMined")
        if beingMined then
            -- Remove BeingMined if asteroid hasn't been hit in 5 seconds
            if currentTime - beingMined.lastHitTime > 5 then
                ECS.removeComponent(asteroidId, "BeingMined")
            end
        end
    end
    
    local hotspotEntities = ECS.getEntitiesWith({"Hotspot", "Attached", "Position"})
    
    for _, hotspotId in ipairs(hotspotEntities) do
        local hotspot = ECS.getComponent(hotspotId, "Hotspot")
        local attached = ECS.getComponent(hotspotId, "Attached")
        local pos = ECS.getComponent(hotspotId, "Position")
        
        if not hotspot or not attached or not pos then
            goto continue
        end
        
        -- Update time since spawn for animation
        hotspot.timeSinceSpawn = hotspot.timeSinceSpawn + dt
        
        -- Update position to follow parent asteroid
        local parentPos = ECS.getComponent(attached.parentId, "Position")
        local parentPoly = ECS.getComponent(attached.parentId, "PolygonShape")
        
        if not parentPos or not parentPoly then
            -- Parent destroyed, remove hotspot
            ECS.destroyEntity(hotspotId)
            goto continue
        end
        
        -- Transform local position to world position
        local rot = parentPoly.rotation or 0
        local lx = attached.localX or 0
        local ly = attached.localY or 0
        local cosr = math.cos(rot)
        local sinr = math.sin(rot)
        local wx = parentPos.x + (lx * cosr - ly * sinr)
        local wy = parentPos.y + (lx * sinr + ly * cosr)
        pos.x = wx
        pos.y = wy
        
        -- Decrement timer
        hotspot.timeRemaining = hotspot.timeRemaining - dt
        
        -- Remove expired hotspots
        if hotspot.timeRemaining <= 0 then
            ECS.destroyEntity(hotspotId)
        end
        
        ::continue::
    end
    
    -- Randomly spawn new hotspots every 15 seconds
    if math.random() < dt / 15 then
        spawnRandomHotspots()
    end
end

return HotspotSystem

