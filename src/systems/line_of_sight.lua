---@diagnostic disable: undefined-global
-- Line of Sight System - Checks if a clear path exists between two points
-- Used for enemy AI to determine if they can fire at the player without obstacles

local ECS = require('src.ecs')

local LineOfSight = {}

-- Check if a line segment intersects with a circle (bounding check)
local function lineCircleIntersect(x1, y1, x2, y2, cx, cy, radius)
    local dx = x2 - x1
    local dy = y2 - y1
    local fx = x1 - cx
    local fy = y1 - cy
    
    local a = dx * dx + dy * dy
    if a < 0.0001 then return false end -- Line is too short
    
    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - radius * radius
    
    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then return false end
    
    discriminant = math.sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)
    
    -- Check if intersection occurs along the line segment (0 to 1)
    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1) or (t1 < 0 and t2 > 1)
end

-- Check if a line segment intersects with a polygon
local function linePolygonIntersect(x1, y1, x2, y2, entityId)
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
    
    -- Check each edge of the polygon
    for i = 1, #transformedVertices do
        local p1 = transformedVertices[i]
        local p2 = transformedVertices[(i % #transformedVertices) + 1]

        local den = (x1 - x2) * (p1.y - p2.y) - (y1 - y2) * (p1.x - p2.x)
        if den ~= 0 then
            local t = ((x1 - p1.x) * (p1.y - p2.y) - (y1 - p1.y) * (p1.x - p2.x)) / den
            local u = -((x1 - x2) * (y1 - p1.y) - (y1 - y2) * (x1 - p1.x)) / den

            if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
                return true
            end
        end
    end

    return false
end

-- Main function: Check if there's a clear line of sight between two points
-- Returns true if path is clear, false if blocked by obstacles
-- Checks asteroids, wreckage, and other polygonal obstacles
function LineOfSight.canSeeTarget(fromX, fromY, toX, toY, excludeEntityId)
    if not fromX or not fromY or not toX or not toY then
        return true -- Safety check
    end
    
    excludeEntityId = excludeEntityId or -1
    
    -- Quick sanity check - if we can't see far from source, allow it
    local dx = toX - fromX
    local dy = toY - fromY
    local distSq = dx * dx + dy * dy
    if distSq < 1 then return true end
    
    local canSee = true
    
    -- Check asteroids (circular collision) - only if not too far
    pcall(function()
        local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Collidable"})
        for _, asteroidId in ipairs(asteroids) do
            if asteroidId ~= excludeEntityId then
                local asteroidPos = ECS.getComponent(asteroidId, "Position")
                local asteroidColl = ECS.getComponent(asteroidId, "Collidable")
                if asteroidPos and asteroidColl then
                    -- Quick distance check first before expensive line-circle test
                    local adx = asteroidPos.x - fromX
                    local ady = asteroidPos.y - fromY
                    local astDistSq = adx * adx + ady * ady
                    local checkDist = (asteroidColl.radius + 50) -- Add buffer
                    if astDistSq < checkDist * checkDist then
                        if lineCircleIntersect(fromX, fromY, toX, toY, asteroidPos.x, asteroidPos.y, asteroidColl.radius) then
                            canSee = false
                            return
                        end
                    end
                end
            end
        end
    end)
    
    if not canSee then return false end
    
    -- Check wreckage (polygon collision)
    pcall(function()
        local wreckages = ECS.getEntitiesWith({"Wreckage", "Position", "PolygonShape"})
        for _, wreckId in ipairs(wreckages) do
            if wreckId ~= excludeEntityId then
                local wreckPos = ECS.getComponent(wreckId, "Position")
                if wreckPos then
                    -- Quick bounding box check first
                    local wdx = wreckPos.x - fromX
                    local wdy = wreckPos.y - fromY
                    local wreckDistSq = wdx * wdx + wdy * wdy
                    if wreckDistSq < 500 * 500 then -- Only check nearby wreckage
                        if linePolygonIntersect(fromX, fromY, toX, toY, wreckId) then
                            canSee = false
                            return
                        end
                    end
                end
            end
        end
    end)
    
    return canSee
end

-- Get the best firing position to hit a target while avoiding obstacles
-- Tries several angles around the target to find an unobstructed shot
-- Returns {x, y} if a clear shot exists, nil otherwise
function LineOfSight.findBestFirePosition(enemyX, enemyY, targetX, targetY, excludeEntityId, searchRadius)
    searchRadius = searchRadius or 100
    
    -- Check direct line first (best case)
    if LineOfSight.canSeeTarget(enemyX, enemyY, targetX, targetY, excludeEntityId) then
        return {x = targetX, y = targetY}
    end
    
    -- Try positions around the target in a circle
    local angleSteps = 8
    for i = 0, angleSteps - 1 do
        local angle = (i / angleSteps) * 2 * math.pi
        local checkX = targetX + math.cos(angle) * searchRadius
        local checkY = targetY + math.sin(angle) * searchRadius
        
        if LineOfSight.canSeeTarget(enemyX, enemyY, checkX, checkY, excludeEntityId) then
            return {x = checkX, y = checkY}
        end
    end
    
    return nil
end

-- Get a target position that is clear of line-of-sight obstacles
-- Used for movement planning to avoid having projectiles blocked
function LineOfSight.findManeuveredPosition(enemyPos, targetPos, currentVel, avoidRadius)
    avoidRadius = avoidRadius or 150
    
    -- Try positions perpendicular to current velocity
    local vx = targetPos.x - enemyPos.x
    local vy = targetPos.y - enemyPos.y
    local vmag = math.sqrt(vx * vx + vy * vy)
    
    if vmag < 0.01 then return nil end
    
    -- Normalized perpendicular vectors
    local perpX = -vy / vmag
    local perpY = vx / vmag
    
    -- Try left and right positions
    local leftX = enemyPos.x + perpX * avoidRadius
    local leftY = enemyPos.y + perpY * avoidRadius
    local rightX = enemyPos.x - perpX * avoidRadius
    local rightY = enemyPos.y - perpY * avoidRadius
    
    if LineOfSight.canSeeTarget(leftX, leftY, targetPos.x, targetPos.y) then
        return {x = leftX, y = leftY}
    end
    
    if LineOfSight.canSeeTarget(rightX, rightY, targetPos.x, targetPos.y) then
        return {x = rightX, y = rightY}
    end
    
    return nil
end

return LineOfSight
