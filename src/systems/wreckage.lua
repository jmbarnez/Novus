---@diagnostic disable: undefined-global
-- Wreckage System - Handles creation and management of salvageable wreckage

local ECS = require('src.ecs')
local Components = require('src.components')

local WrackageSystem = {
    name = "WrackageSystem",
    priority = 7
}

-- Spawn wreckage pieces around a destroyed ship
-- @param x number: X position of ship destruction
-- @param y number: Y position of ship destruction
-- @param sourceShip string: Identifier for the source ship type
function WrackageSystem.spawnWrackage(x, y, sourceShip)
    sourceShip = sourceShip or "unknown"
    
    local wreckageCount = math.random(3, 6)  -- 3-6 wreckage pieces per destroyed ship
    
    for i = 1, wreckageCount do
        -- Random size for variety
        local size = math.random(8, 16)
        
        -- Random spawn position around destruction point
        local angle = (math.random() * math.pi * 2)  -- 0-2π radians
        local distance = math.random(40, 100)  -- Distance from center
        
        local wreckageX = x + math.cos(angle) * distance
        local wreckageY = y + math.sin(angle) * distance
        
        -- Random velocity away from destruction point
        local speed = math.random(20, 60)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        -- Random rotation
        local rotationSpeed = (math.random() - 0.5) * 2 * math.pi  -- -π to π radians per second
        
        -- 50% chance to drop scrap when salvaged
        local dropsScrap = math.random() < 0.5
        
        -- Create wreckage entity
        local wreckageId = ECS.createEntity()
        
        -- Core components
        ECS.addComponent(wreckageId, "Position", Components.Position(wreckageX, wreckageY))
        ECS.addComponent(wreckageId, "Velocity", Components.Velocity(vx, vy))
        ECS.addComponent(wreckageId, "Physics", Components.Physics(0.97, 0.3))  -- Some friction, light mass
        ECS.addComponent(wreckageId, "AngularVelocity", Components.AngularVelocity(rotationSpeed))
        
        -- Wreckage-specific components
        ECS.addComponent(wreckageId, "Wreckage", Components.Wreckage(sourceShip))
        
        -- Collision and durability
        ECS.addComponent(wreckageId, "Collidable", Components.Collidable(size / 2))
        ECS.addComponent(wreckageId, "Durability", Components.Durability(size * 1.5, size * 1.5))  -- Health based on size
        
        -- Visual representation - angular metal shards
        ECS.addComponent(wreckageId, "PolygonShape", Components.PolygonShape(WrackageSystem.generateWreckageShape(size), 0))
        ECS.addComponent(wreckageId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.4, 0.4, 0.45, 1}))  -- Dark gray metal
        
        -- Store whether this wreckage drops scrap
        ECS.addComponent(wreckageId, "LootDrop", {dropsScrap = dropsScrap, droppedScrap = false})
    end
end

-- Generate a random angular polygon shape for wreckage
function WrackageSystem.generateWreckageShape(size)
    local vertices = {}
    local sides = math.random(4, 6)
    
    for i = 1, sides do
        local angle = (i / sides) * math.pi * 2
        local distance = size * (0.7 + math.random() * 0.3)  -- Slight randomness in distance
        table.insert(vertices, {x = math.cos(angle) * distance, y = math.sin(angle) * distance})
    end
    
    return vertices
end

return WrackageSystem
