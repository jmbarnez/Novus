-- Collision System - Handles player-specific collisions
-- Player collides with all collidable objects
-- Physics-based collisions between entities are handled by PhysicsCollisionSystem

local ECS = require('src.ecs')
local PhysicsSystem = require('src.systems.physics')

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

    for i = 1, #transformedVertices do
        local p1 = transformedVertices[i]
        local p2 = transformedVertices[(i % #transformedVertices) + 1]

        -- Check for intersection between the two line segments
        local den = (x1 - x2) * (p1.y - p2.y) - (y1 - y2) * (p1.x - p2.x)
        if den ~= 0 then
            local t = ((x1 - p1.x) * (p1.y - p2.y) - (y1 - p1.y) * (p1.x - p2.x)) / den
            local u = -((x1 - x2) * (y1 - p1.y) - (y1 - y2) * (x1 - p1.x)) / den

            if t > 0 and t < 1 and u > 0 and u < 1 then
                -- Calculate the intersection point
                local intersectionX = x1 + t * (x2 - x1)
                local intersectionY = y1 + t * (y2 - y1)
                return {x = intersectionX, y = intersectionY}
            end
        end
    end

    return nil
end
local function checkBoundingCircles(pos1, coll1, pos2, coll2)
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < (coll1.radius + coll2.radius)
end

local function pointInPolygon(x, y, vertices)
    local inside = false
    local j = #vertices
    
    for i = 1, #vertices do
        local vi = vertices[i]
        local vj = vertices[j]
        
        if ((vi.y > y) ~= (vj.y > y)) and (x < (vj.x - vi.x) * (y - vi.y) / (vj.y - vi.y) + vi.x) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

local function pointToLineSegmentDistance(px, py, x1, y1, x2, y2)
    local A = px - x1
    local B = py - y1
    local C = x2 - x1
    local D = y2 - y1
    
    local dot = A * C + B * D
    local lenSq = C * C + D * D
    
    if lenSq == 0 then
        -- Line segment is actually a point
        return math.sqrt(A * A + B * B)
    end
    
    local param = dot / lenSq
    
    local xx, yy
    if param < 0 then
        xx, yy = x1, y1
    elseif param > 1 then
        xx, yy = x2, y2
    else
        xx = x1 + param * C
        yy = y1 + param * D
    end
    
    local dx = px - xx
    local dy = py - yy
    return math.sqrt(dx * dx + dy * dy)
end

-- Check collision between polygon and circle using SAT (Separating Axis Theorem)
-- @param polygonPos table: Polygon entity position
-- @param polygonShape table: Polygon shape component
-- @param circlePos table: Circle position
-- @param circleRadius number: Circle radius
-- @return boolean: True if collision detected
local function checkPolygonCircleCollision(polygonPos, polygonShape, circlePos, circleRadius)
    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation
    
    if #vertices < 3 then return false end
    
    -- Transform circle position to polygon's local space
    local dx = circlePos.x - polygonPos.x
    local dy = circlePos.y - polygonPos.y
    
    -- Apply inverse rotation
    local cos = math.cos(-rotation)
    local sin = math.sin(-rotation)
    local localX = dx * cos - dy * sin
    local localY = dx * sin + dy * cos
    
    -- Check if circle center is inside polygon
    local inside = pointInPolygon(localX, localY, vertices)
    if inside then return true end
    
    -- Check distance from circle to each edge
    for i = 1, #vertices do
        local v1 = vertices[i]
        local v2 = vertices[(i % #vertices) + 1]
        
        local dist = pointToLineSegmentDistance(localX, localY, v1.x, v1.y, v2.x, v2.y)
        if dist <= circleRadius then
            return true
        end
    end
    
    return false
end

-- Check collision between two polygons using SAT (Separating Axis Theorem)
-- @param polygon1Pos table: First polygon entity position
-- @param polygon1Shape table: First polygon shape component
-- @param polygon2Pos table: Second polygon entity position
-- @param polygon2Shape table: Second polygon shape component
-- @return boolean: True if collision detected
local function checkPolygonPolygonCollision(polygon1Pos, polygon1Shape, polygon2Pos, polygon2Shape)
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

    local function getAxes(vertices)
        local axes = {}
        for i = 1, #vertices do
            local p1 = vertices[i]
            local p2 = vertices[(i % #vertices) + 1]
            local edge = {x = p2.x - p1.x, y = p2.y - p1.y}
            local normal = {x = -edge.y, y = edge.x} -- Perpendicular vector
            local length = math.sqrt(normal.x * normal.x + normal.y * normal.y)
            if length > 0 then
                table.insert(axes, {x = normal.x / length, y = normal.y / length}) -- Normalized normal
            end
        end
        return axes
    end

    local function project(axis, vertices)
        local minProjection = (vertices[1].x * axis.x) + (vertices[1].y * axis.y)
        local maxProjection = minProjection
        for i = 2, #vertices do
            local projection = (vertices[i].x * axis.x) + (vertices[i].y * axis.y)
            minProjection = math.min(minProjection, projection)
            maxProjection = math.max(maxProjection, projection)
        end
        return minProjection, maxProjection
    end

    local transformedVertices1 = getTransformedVertices(polygon1Pos, polygon1Shape.vertices, polygon1Shape.rotation)
    local transformedVertices2 = getTransformedVertices(polygon2Pos, polygon2Shape.vertices, polygon2Shape.rotation)

    local axes = getAxes(transformedVertices1)
    for _, axis in ipairs(getAxes(transformedVertices2)) do
        table.insert(axes, axis)
    end

    local minOverlap = nil
    local smallestAxis = nil

    for _, axis in ipairs(axes) do
        local min1, max1 = project(axis, transformedVertices1)
        local min2, max2 = project(axis, transformedVertices2)

        local overlap = math.min(max1, max2) - math.max(min1, min2)

        if overlap < 0 then
            return false, nil, nil -- No collision
        end

        if minOverlap == nil or overlap < minOverlap then
            minOverlap = overlap
            smallestAxis = axis
        end
    end

    if smallestAxis then
        -- Ensure the normal is pointing from polygon1 to polygon2
        local direction = {x = polygon2Pos.x - polygon1Pos.x, y = polygon2Pos.y - polygon1Pos.y}
        if (direction.x * smallestAxis.x + direction.y * smallestAxis.y) < 0 then
            smallestAxis.x = -smallestAxis.x
            smallestAxis.y = -smallestAxis.y
        end
        return true, smallestAxis, minOverlap
    end

    return false, nil, nil
end

local function handleCollision(entity1Id, entity2Id, normal, depth)
    -- Ensure normal is never nil
    if not normal or not normal.x or not normal.y then
        normal = {x = 0, y = 1}
    end
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
        
        -- Get player entity
        local playerEntities = ECS.getEntitiesWith({"InputControlled", "Position", "Collidable"})
        if #playerEntities == 0 then return end
        
        local playerId = playerEntities[1]
        local playerPos = ECS.getComponent(playerId, "Position")
        local playerCollidable = ECS.getComponent(playerId, "Collidable")
        
        -- Check collisions between player and all other collidables
        -- Note: Items are handled by PhysicsCollisionSystem for automatic physics responses
        for _, entityId in ipairs(collidableEntities) do
            if entityId ~= playerId then -- Don't check player with itself
                local entityPos = ECS.getComponent(entityId, "Position")
                local entityCollidable = ECS.getComponent(entityId, "Collidable")
                
                -- Broad-phase: Check bounding circles
                local broadPhaseHit = checkBoundingCircles(playerPos, playerCollidable, entityPos, entityCollidable)

                if broadPhaseHit then
                    local playerPolygon = ECS.getComponent(playerId, "PolygonShape")
                    local entityPolygon = ECS.getComponent(entityId, "PolygonShape")

                    if playerPolygon and entityPolygon then
                        -- Both are polygons, use polygon-polygon collision
                        local isColliding, normal, depth = checkPolygonPolygonCollision(playerPos, playerPolygon, entityPos, entityPolygon)
                        if isColliding then
                            handleCollision(playerId, entityId, normal, depth)
                        end
                    elseif playerPolygon then
                        -- Player is polygon, entity is circle (for future use)
                        if checkPolygonCircleCollision(playerPos, playerPolygon, entityPos, entityCollidable.radius) then
                            handleCollision(playerId, entityId)
                        end
                    elseif entityPolygon then
                        -- Player is circle, entity is polygon (this is for asteroids, but player is now polygon)
                        if checkPolygonCircleCollision(entityPos, entityPolygon, playerPos, playerCollidable.radius) then
                            handleCollision(playerId, entityId)
                        end
                    else
                        -- Both are circles (should not happen with asteroids or player now)
                        handleCollision(playerId, entityId)
                    end
                end
            end
        end
    end
}

return {
    CollisionSystem = CollisionSystem,
    linePolygonIntersect = linePolygonIntersect,
}