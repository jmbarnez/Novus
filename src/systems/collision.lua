-- Collision System - Handles player-specific collisions
-- Player collides with all collidable objects
-- Physics-based collisions between entities are handled by PhysicsCollisionSystem

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Quadtree = require('src.systems.quadtree')
local CollisionUtils = require('src.collision_utils')

local CollisionSystem = {
    name = "CollisionSystem",
    priority = 4
}

-- Helper functions for collision detection

-- New helper function to check for line-segment to polygon intersection
function linePolygonIntersect(x1, y1, x2, y2, entityId)
    local polygonShape = ECS.getComponent(entityId, "PolygonShape")
    if not polygonShape then return false end

    local pos = ECS.getComponent(entityId, "Position")
    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation

    local function getTransformedVertices(pos, vertices, rotation)
        local transformed = {}
        local cos = math.cos(rotation)
        local sin = math.sin(rotation)
        for _, v in ipairs(vertices) do
            local rx = v.x * cos - v.y * sin
            local ry = v.x * sin + v.y * cos
            table.insert(transformed, {x = pos.x + rx, y = pos.y + ry})
        end
        return transformed
    end

    local transformedVertices = getTransformedVertices(pos, vertices, rotation)
    
    local closestIntersection = nil
    local closestDistSq = math.huge

    -- Check each edge of the polygon
    for i = 1, #transformedVertices do
        local p1 = transformedVertices[i]
        local p2 = transformedVertices[(i % #transformedVertices) + 1]

        -- Check for intersection between the two line segments
        local den = (x1 - x2) * (p1.y - p2.y) - (y1 - y2) * (p1.x - p2.x)
        if den ~= 0 then
            local t = ((x1 - p1.x) * (p1.y - p2.y) - (y1 - p1.y) * (p1.x - p2.x)) / den
            local u = -((x1 - x2) * (y1 - p1.y) - (y1 - y2) * (x1 - p1.x)) / den

            -- Accept intersection if both parameters are in valid range (0-1 for both line segments)
            if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
                -- Calculate the intersection point
                local intersectionX = x1 + t * (x2 - x1)
                local intersectionY = y1 + t * (y2 - y1)
                
                -- Find the closest intersection to the laser origin (x1, y1)
                local distSq = (intersectionX - x1)^2 + (intersectionY - y1)^2
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestIntersection = {x = intersectionX, y = intersectionY}
                end
            end
        end
    end

    return closestIntersection
end

local function handleCollision(entity1Id, entity2Id, normal, depth)
    -- Ensure normal is never nil
    if not normal or not normal.x or not normal.y then
        normal = {x = 0, y = 1}
    end
    -- Ensure depth is never nil
    depth = depth or 0
    local pos1 = ECS.getComponent(entity1Id, "Position")
    local vel1 = ECS.getComponent(entity1Id, "Velocity")
    local phys1 = ECS.getComponent(entity1Id, "Physics")

    local pos2 = ECS.getComponent(entity2Id, "Position")
    local vel2 = ECS.getComponent(entity2Id, "Velocity")
    local phys2 = ECS.getComponent(entity2Id, "Physics")

    if not vel1 or not vel2 or not phys1 or not phys2 then
        -- No physics response if one of the entities doesn't have velocity or physics
        return
    end

    -- Calculate relative velocity
    local rv = {x = vel2.vx - vel1.vx, y = vel2.vy - vel1.vy}

    -- Calculate relative velocity in terms of the normal direction
    local velAlongNormal = rv.x * normal.x + rv.y * normal.y

    -- Do not resolve if velocities are separating
    if velAlongNormal > 0 then
        return
    end

    -- Use a restitution of 0 (inelastic collision) for now
    local e = 0.0

    -- Calculate impulse scalar
    local j = -(1 + e) * velAlongNormal
    j = j / (1 / phys1.mass + 1 / phys2.mass)

    -- Apply impulse
    local impulse = {x = j * normal.x, y = j * normal.y}
    vel1.vx = vel1.vx - (1 / phys1.mass) * impulse.x
    vel1.vy = vel1.vy - (1 / phys1.mass) * impulse.y
    vel2.vx = vel2.vx + (1 / phys2.mass) * impulse.x
    vel2.vy = vel2.vy + (1 / phys2.mass) * impulse.y

    -- Positional correction
    local percent = 0.2 -- 20%
    local slop = 0.01 -- 0.01
    local correction = {
        x = math.max(depth - slop, 0) / (1 / phys1.mass + 1 / phys2.mass) * percent * normal.x,
        y = math.max(depth - slop, 0) / (1 / phys1.mass + 1 / phys2.mass) * percent * normal.y
    }
    pos1.x = pos1.x - (1 / phys1.mass) * correction.x
    pos1.y = pos1.y - (1 / phys1.mass) * correction.y
    pos2.x = pos2.x + (1 / phys2.mass) * correction.x
    pos2.y = pos2.y + (1 / phys2.mass) * correction.y
end

local CollisionSystem = {
    name = "CollisionSystem",

    update = function(dt)
        -- Get all collidable entities
        local collidableEntities = ECS.getEntitiesWith({"Collidable", "Position"})
        
        -- Get the pilot and their controlled drone
        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        if #playerEntities == 0 then return end
        
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if not input or not input.targetEntity then return end
        local playerId = input.targetEntity
        local playerPos = ECS.getComponent(playerId, "Position")
        local playerCollidable = ECS.getComponent(playerId, "Collidable")
        
        if not playerPos or not playerCollidable then return end
        
        -- [QUADTREE OPTIMIZATION] Build quadtree for spatial partitioning
        -- Only query nearby entities instead of checking all collidables
        local quadtree = Quadtree.create(
            Constants.world_min_x,
            Constants.world_min_y,
            Constants.world_width,
            Constants.world_height,
            0  -- Starting depth
        )
        
        -- Insert all collidable entities into quadtree
        for _, entityId in ipairs(collidableEntities) do
            if entityId ~= playerId then  -- Skip player itself
                local pos = ECS.getComponent(entityId, "Position")
                local coll = ECS.getComponent(entityId, "Collidable")
                if pos and coll then
                    Quadtree.insert(quadtree, entityId, pos, coll.radius)
                end
            end
        end
        
        -- Query quadtree for nearby entities (use radius * 3 for safety margin)
        local searchRadius = playerCollidable.radius * 3
        local nearbyEntities = Quadtree.getNearby(quadtree, playerPos.x, playerPos.y, searchRadius)
        
        -- Check collisions between player and nearby collidables
        -- Note: Items are handled by PhysicsCollisionSystem for automatic physics responses
        for _, entityData in ipairs(nearbyEntities) do
            local entityId = entityData.id  -- Extract ID from quadtree result
            local entityPos = ECS.getComponent(entityId, "Position")
            local entityCollidable = ECS.getComponent(entityId, "Collidable")
            
            if not entityPos or not entityCollidable then
                goto continue_entity
            end
            -- Broad-phase: Check bounding circles
            local broadPhaseHit = CollisionUtils.checkBoundingCircles(playerPos.x, playerPos.y, playerCollidable.radius, entityPos.x, entityPos.y, entityCollidable.radius)

            if broadPhaseHit then
                local playerPolygon = ECS.getComponent(playerId, "PolygonShape")
                local entityPolygon = ECS.getComponent(entityId, "PolygonShape")

                if playerPolygon and entityPolygon then
                    -- Both are polygons, use polygon-polygon collision
                    -- Transform polygons to world space for CollisionUtils
                    local playerWorldPoly = CollisionUtils.transformPolygon(playerPos, playerPolygon)
                    local entityWorldPoly = CollisionUtils.transformPolygon(entityPos, entityPolygon)
                    
                    local isColliding = CollisionUtils.checkPolygonPolygonCollision(playerWorldPoly, entityWorldPoly)
                    if isColliding then
                        -- Calculate normal and depth manually for handleCollision
                        local dx = entityPos.x - playerPos.x
                        local dy = entityPos.y - playerPos.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        local normal = dist > 0 and {x = dx / dist, y = dy / dist} or {x = 0, y = 1}
                        local depth = playerCollidable.radius + entityCollidable.radius - dist
                        handleCollision(playerId, entityId, normal, depth)
                    end
                elseif playerPolygon then
                    -- Player is polygon, entity is circle
                    local playerWorldPoly = CollisionUtils.transformPolygon(playerPos, playerPolygon)
                    if CollisionUtils.checkPolygonCircleCollision(playerWorldPoly, entityPos.x, entityPos.y, entityCollidable.radius) then
                        handleCollision(playerId, entityId)
                    end
                elseif entityPolygon then
                    -- Player is circle, entity is polygon
                    local entityWorldPoly = CollisionUtils.transformPolygon(entityPos, entityPolygon)
                    if CollisionUtils.checkPolygonCircleCollision(entityWorldPoly, playerPos.x, playerPos.y, playerCollidable.radius) then
                        handleCollision(playerId, entityId)
                    end
                else
                    -- Both are circles (should not happen with asteroids or player now)
                    handleCollision(playerId, entityId)
                end
            end
            
            ::continue_entity::
        end
    end
}

return {
    CollisionSystem = CollisionSystem,
    linePolygonIntersect = linePolygonIntersect,
}