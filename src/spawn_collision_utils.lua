-- Universal Spawn Collision Detection System
-- Ensures no procedurally spawned objects overlap with existing entities
-- Works with all entity types: asteroids, enemies, stations, items, etc.

local ECS = require('src.ecs')
local Constants = require('src.constants')
local CollisionUtils = require('src.collision_utils')

local SpawnCollisionUtils = {}

-- Global registry of all spawned positions and their collision data
-- This tracks all entities that have been spawned to prevent overlaps
local spawnedEntities = {}

-- Clear the spawn registry (call when starting a new world)
function SpawnCollisionUtils.clearRegistry()
    spawnedEntities = {}
end

-- Register a spawned entity in the collision registry
-- @param entityId number: Entity ID
-- @param x number: X position
-- @param y number: Y position
-- @param radius number: Collision radius
-- @param entityType string: Type of entity ("asteroid", "enemy", "station", "item", etc.)
function SpawnCollisionUtils.registerEntity(entityId, x, y, radius, entityType)
    table.insert(spawnedEntities, {
        id = entityId,
        x = x,
        y = y,
        radius = radius,
        type = entityType or "unknown"
    })
end

-- Check if a position is safe to spawn at (no collisions with existing entities)
-- @param x number: X position to check
-- @param y number: Y position to check
-- @param radius number: Collision radius of the entity to spawn
-- @param minDistance number: Minimum distance from other entities (default: 150)
-- @param excludeTypes table: Array of entity types to ignore (optional)
-- @return boolean: true if position is safe, false if collision detected
function SpawnCollisionUtils.isPositionSafe(x, y, radius, minDistance, excludeTypes)
    minDistance = minDistance or 150
    excludeTypes = excludeTypes or {}
    
    -- Check against all registered spawned entities
    for _, entity in ipairs(spawnedEntities) do
        -- Skip excluded entity types
        local shouldExclude = false
        for _, excludeType in ipairs(excludeTypes) do
            if entity.type == excludeType then
                shouldExclude = true
                break
            end
        end
        if shouldExclude then
            goto continue
        end
        
        -- Calculate distance between positions
        local dx = x - entity.x
        local dy = y - entity.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- Check if too close (considering both radii and minimum distance)
        local requiredDistance = radius + entity.radius + minDistance
        if distance < requiredDistance then
            return false
        end
        
        ::continue::
    end
    
    -- Also check against existing ECS entities with Position and Collidable components
    local existingEntities = ECS.getEntitiesWith({"Position", "Collidable"})
    for _, entityId in ipairs(existingEntities) do
        local pos = ECS.getComponent(entityId, "Position")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if pos and coll then
            local dx = x - pos.x
            local dy = y - pos.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            local requiredDistance = radius + coll.radius + minDistance
            if distance < requiredDistance then
                return false
            end
        end
    end
    
    return true
end

-- Find a safe spawn position with collision avoidance
-- @param centerX number: Center X for search area
-- @param centerY number: Center Y for search area
-- @param searchRadius number: Radius to search within
-- @param entityRadius number: Collision radius of entity to spawn
-- @param minDistance number: Minimum distance from other entities
-- @param maxAttempts number: Maximum attempts to find safe position
-- @param excludeTypes table: Array of entity types to ignore
-- @return number, number, boolean: x, y, success (nil, nil, false if failed)
function SpawnCollisionUtils.findSafePosition(centerX, centerY, searchRadius, entityRadius, minDistance, maxAttempts, excludeTypes)
    maxAttempts = maxAttempts or 50
    minDistance = minDistance or 150
    
    for attempt = 1, maxAttempts do
        -- Generate random position within search radius
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * searchRadius
        local x = centerX + math.cos(angle) * distance
        local y = centerY + math.sin(angle) * distance
        
        -- Check if position is safe
        if SpawnCollisionUtils.isPositionSafe(x, y, entityRadius, minDistance, excludeTypes) then
            return x, y, true
        end
    end
    
    return nil, nil, false
end

-- Find a safe spawn position within world boundaries
-- @param entityRadius number: Collision radius of entity to spawn
-- @param minDistance number: Minimum distance from other entities
-- @param maxAttempts number: Maximum attempts to find safe position
-- @param excludeTypes table: Array of entity types to ignore
-- @return number, number, boolean: x, y, success
function SpawnCollisionUtils.findSafePositionInWorld(entityRadius, minDistance, maxAttempts, excludeTypes)
    maxAttempts = maxAttempts or 100
    minDistance = minDistance or 150
    
    for attempt = 1, maxAttempts do
        -- Generate random position within world boundaries
        local x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
        local y = Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y)
        
        -- Check if position is safe
        if SpawnCollisionUtils.isPositionSafe(x, y, entityRadius, minDistance, excludeTypes) then
            return x, y, true
        end
    end
    
    return nil, nil, false
end

-- Advanced collision detection that considers polygon shapes
-- @param x number: X position to check
-- @param y number: Y position to check
-- @param entityRadius number: Collision radius of entity to spawn
-- @param minDistance number: Minimum distance from other entities
-- @param excludeTypes table: Array of entity types to ignore
-- @return boolean: true if position is safe
function SpawnCollisionUtils.isPositionSafeAdvanced(x, y, entityRadius, minDistance, excludeTypes)
    minDistance = minDistance or 150
    excludeTypes = excludeTypes or {}
    
    -- Check against registered spawned entities
    for _, entity in ipairs(spawnedEntities) do
        local shouldExclude = false
        for _, excludeType in ipairs(excludeTypes) do
            if entity.type == excludeType then
                shouldExclude = true
                break
            end
        end
        if shouldExclude then
            goto continue
        end
        
        -- Simple circle collision check
        local dx = x - entity.x
        local dy = y - entity.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local requiredDistance = entityRadius + entity.radius + minDistance
        
        if distance < requiredDistance then
            return false
        end
        
        ::continue::
    end
    
    -- Check against existing ECS entities with advanced collision detection
    local existingEntities = ECS.getEntitiesWith({"Position", "Collidable"})
    for _, entityId in ipairs(existingEntities) do
        local pos = ECS.getComponent(entityId, "Position")
        local coll = ECS.getComponent(entityId, "Collidable")
        local polygon = ECS.getComponent(entityId, "PolygonShape")
        
        if pos and coll then
            -- Check if entity has polygon shape for more precise collision
            if polygon then
                -- Transform polygon to world space
                local worldPolygon = CollisionUtils.transformPolygon(pos, polygon)
                
                -- Check if spawn position is inside polygon
                if CollisionUtils.pointInPolygon(x, y, worldPolygon) then
                    return false
                end
                
                -- Check distance to polygon edges
                local minDistToPolygon = math.huge
                for i = 1, #worldPolygon do
                    local j = (i % #worldPolygon) + 1
                    local x1, y1 = worldPolygon[i][1], worldPolygon[i][2]
                    local x2, y2 = worldPolygon[j][1], worldPolygon[j][2]
                    local dist = CollisionUtils.pointToLineSegmentDistance(x, y, x1, y1, x2, y2)
                    minDistToPolygon = math.min(minDistToPolygon, dist)
                end
                
                if minDistToPolygon < entityRadius + minDistance then
                    return false
                end
            else
                -- Simple circle collision
                local dx = x - pos.x
                local dy = y - pos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                local requiredDistance = entityRadius + coll.radius + minDistance
                
                if distance < requiredDistance then
                    return false
                end
            end
        end
    end
    
    return true
end

-- Get collision statistics for debugging
-- @return table: Statistics about spawned entities
function SpawnCollisionUtils.getStats()
    local stats = {
        totalEntities = #spawnedEntities,
        byType = {}
    }
    
    for _, entity in ipairs(spawnedEntities) do
        stats.byType[entity.type] = (stats.byType[entity.type] or 0) + 1
    end
    
    return stats
end

-- Remove an entity from the collision registry (when entity is destroyed)
-- @param entityId number: Entity ID to remove
function SpawnCollisionUtils.unregisterEntity(entityId)
    for i = #spawnedEntities, 1, -1 do
        if spawnedEntities[i].id == entityId then
            table.remove(spawnedEntities, i)
        end
    end
end

return SpawnCollisionUtils
