-- Physics Collision System - Universal collision handling for all physics entities
-- Handles collisions between any entities with Position, Velocity, Physics, and Collidable components


local ECS = require('src.ecs')
local Constants = require('src.constants')
local Quadtree = require('src.systems.quadtree')
local CollisionUtils = require('src.collision_utils')
local EntityHelpers = require('src.entity_helpers')

-- Frame counter for optimization
local frameCounter = 0

local function hasRotationChanged(poly1, poly2, rotationThreshold)
    rotationThreshold = rotationThreshold or 0.1  -- ~5.7 degrees
    local rot1Changed = poly1 and math.abs(poly1.rotation - (poly1.prevRotation or 0)) > rotationThreshold or false
    local rot2Changed = poly2 and math.abs(poly2.rotation - (poly2.prevRotation or 0)) > rotationThreshold or false
    return rot1Changed or rot2Changed
end

local function checkSweptCircleCircle(oldPos, newPos, radius1, staticPos, radius2)
    local minDist = radius1 + radius2
    
    -- Vector from old to new position
    local dx = newPos.x - oldPos.x
    local dy = newPos.y - oldPos.y
    
    -- Vector from old position to static circle
    local fx = oldPos.x - staticPos.x
    local fy = oldPos.y - staticPos.y
    
    local a = dx * dx + dy * dy
    local b = 2 * (fx * dx + fy * dy)
    local c = (fx * fx + fy * fy) - (minDist * minDist)
    
    if a < 0.0001 then
        -- Movement is negligible, do static check
        local dist = math.sqrt(fx * fx + fy * fy)
        return dist < minDist, 0  -- Return collision flag and time of impact
    end
    
    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then
        return false, 1  -- No intersection
    end
    
    discriminant = math.sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)
    
    -- Check if collision happens within movement (t in [0, 1])
    -- Return earliest collision time
    if t1 >= 0 and t1 <= 1 then
        return true, t1
    elseif t2 >= 0 and t2 <= 1 then
        return true, t2
    elseif t1 < 0 and t2 > 1 then
        return true, 0  -- Object is moving through target
    end
    
    return false, 1
end

-- Helper: Swept circle-polygon collision for CCD
-- Checks if a circle swept from oldPos to newPos collides with a static polygon
local function checkSweptCirclePolygon(oldPos, newPos, radius, polygonPos, polygonShape)
    -- Transform polygon to world space
    local polygonWorld = CollisionUtils.transformPolygon(polygonPos, polygonShape)
    
    -- Check collision at current position first
    if CollisionUtils.checkPolygonCircleCollision(polygonWorld, newPos.x, newPos.y, radius) then
        return true, newPos
    end
    -- Check collision at previous position
    if CollisionUtils.checkPolygonCircleCollision(polygonWorld, oldPos.x, oldPos.y, radius) then
        return true, oldPos
    end
    -- Check if sweep line intersects polygon edges
    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    -- Transform vertices to world space
    local transformedVertices = {}
    for _, v in ipairs(vertices) do
        local rx = v.x * cos - v.y * sin
        local ry = v.x * sin + v.y * cos
        table.insert(transformedVertices, {x = polygonPos.x + rx, y = polygonPos.y + ry})
    end
    -- Check sweep line against each edge
    local sweepRadius = radius
    local closestImpact = nil
    local closestDist = math.huge
    for i = 1, #transformedVertices do
        local v1 = transformedVertices[i]
        local v2 = transformedVertices[(i % #transformedVertices) + 1]
        local edgeDx = v2.x - v1.x
        local edgeDy = v2.y - v1.y
        local edgeLen = math.sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        if edgeLen > 0 then
            local sweepDx = newPos.x - oldPos.x
            local sweepDy = newPos.y - oldPos.y
            local f1x = oldPos.x - v1.x
            local f1y = oldPos.y - v1.y
            local sweepDot = sweepDx * sweepDx + sweepDy * sweepDy
            if sweepDot > 0.0001 then
                local t = -(f1x * sweepDx + f1y * sweepDy) / sweepDot
                t = math.max(0, math.min(1, t))
                local px = oldPos.x + t * sweepDx
                local py = oldPos.y + t * sweepDy
                local edgeDot2 = (px - v1.x) * edgeDx + (py - v1.y) * edgeDy
                local s = edgeDot2 / (edgeLen * edgeLen)
                s = math.max(0, math.min(1, s))
                local ex = v1.x + s * edgeDx
                local ey = v1.y + s * edgeDy
                local dx = px - ex
                local dy = py - ey
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < sweepRadius and dist < closestDist then
                    closestDist = dist
                    closestImpact = {x = px, y = py}
                end
            end
        end
    end
    if closestImpact then
        return true, closestImpact
    end
    return false
end

-- Local SAT implementation for polygon-polygon with normal/depth return
local function checkPolygonPolygonCollisionSAT(polygon1Pos, polygon1Shape, polygon2Pos, polygon2Shape)
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
            local normal = {x = -edge.y, y = edge.x}
            local length = math.sqrt(normal.x * normal.x + normal.y * normal.y)
            if length > 0 then
                table.insert(axes, {x = normal.x / length, y = normal.y / length})
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
            return false, nil, nil
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

-- Find closest point on polygon to a circle, with proper normal
local function findCollisionNormal(polygonPos, polygonShape, circlePos, circleRadius)
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
    
    local transformedVertices = getTransformedVertices(polygonPos, vertices, rotation)
    
    local closestDist = math.huge
    local closestPoint = {x = polygonPos.x, y = polygonPos.y}
    local closestNormal = {x = 0, y = 1}
    
    for i = 1, #transformedVertices do
        local v1 = transformedVertices[i]
        local v2 = transformedVertices[(i % #transformedVertices) + 1]
        
        -- Find closest point on this edge
        local A = circlePos.x - v1.x
        local B = circlePos.y - v1.y
        local C = v2.x - v1.x
        local D = v2.y - v1.y
        
        local dot = A * C + B * D
        local lenSq = C * C + D * D
        
        local param = 0
        if lenSq > 0 then
            param = math.max(0, math.min(1, dot / lenSq))
        end
        
        local px = v1.x + param * C
        local py = v1.y + param * D
        
        local dx = circlePos.x - px
        local dy = circlePos.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        
        if dist < closestDist then
            closestDist = dist
            closestPoint = {x = px, y = py}
            -- Normal is perpendicular to edge, pointing outward
            local edgeLen = math.sqrt(C * C + D * D)
            if edgeLen > 0 then
                local edgeNx = -D / edgeLen
                local edgeNy = C / edgeLen
                -- Flip normal if needed (should point from polygon to circle)
                if edgeNx * dx + edgeNy * dy < 0 then
                    edgeNx = -edgeNx
                    edgeNy = -edgeNy
                end
                closestNormal = {x = edgeNx, y = edgeNy}
            end
        end
    end
    
    return {normal = closestNormal, distance = closestDist, point = closestPoint}
end

-- Apply impulse-based collision response
-- Apply impulse-based collision response with angular momentum
local function resolveCollision(entity1, entity2, normal, depth)
    local pos1 = entity1.pos
    local vel1 = entity1.vel
    local phys1 = entity1.phys
    local angularVel1 = entity1.angularVel
    local rotMass1 = entity1.rotMass
    
    local pos2 = entity2.pos
    local vel2 = entity2.vel
    local phys2 = entity2.phys
    local angularVel2 = entity2.angularVel
    local rotMass2 = entity2.rotMass
    
    -- Calculate relative velocity
    local rv = {x = vel2.vx - vel1.vx, y = vel2.vy - vel1.vy}
    local velAlongNormal = rv.x * normal.x + rv.y * normal.y
    
    -- Only resolve if objects are moving toward each other
    if velAlongNormal >= 0 then
        return
    end
    
    -- Calculate impulse for linear collision response
    local restitution = 0.3  -- Some bounce for realistic space physics (was 0.0)
    local j = -(1 + restitution) * velAlongNormal
    j = j / (1 / phys1.mass + 1 / phys2.mass)
    
    -- Calculate contact point (approximate - center of collision)
    local contactX = (pos1.x + pos2.x) / 2
    local contactY = (pos1.y + pos2.y) / 2
    
    -- Calculate torque (rotational impulse)
    -- Torque = r x F (cross product of radius and impulse force)
    local r1x = contactX - pos1.x
    local r1y = contactY - pos1.y
    local r2x = contactX - pos2.x
    local r2y = contactY - pos2.y
    
    local impulseX = j * normal.x
    local impulseY = j * normal.y
    
    -- Cross product for torque: r x F = r.x * F.y - r.y * F.x
    local torque1 = r1x * impulseY - r1y * impulseX
    local torque2 = r2x * impulseY - r2y * impulseX
    
    -- Apply linear impulse
    vel1.vx = vel1.vx - (1 / phys1.mass) * impulseX
    vel1.vy = vel1.vy - (1 / phys1.mass) * impulseY
    vel2.vx = vel2.vx + (1 / phys2.mass) * impulseX
    vel2.vy = vel2.vy + (1 / phys2.mass) * impulseY
    
    -- Apply angular impulse (only if entity has rotational properties)
    if angularVel1 and rotMass1 then
        angularVel1.omega = angularVel1.omega - torque1 / rotMass1.inertia
    end
    if angularVel2 and rotMass2 then
        angularVel2.omega = angularVel2.omega + torque2 / rotMass2.inertia
    end
    
    -- AGGRESSIVE Positional correction to prevent penetration
    -- Separate objects immediately if interpenetrating
    local percent = 0.8  -- Increased from 0.3 - more aggressive separation
    local slop = 0.01   -- Reduced from 0.5 - stricter penetration threshold
    local correction = math.max(depth - slop, 0) / (1 / phys1.mass + 1 / phys2.mass) * percent
    
    -- Push objects apart along collision normal
    pos1.x = pos1.x - (1 / phys1.mass) * correction * normal.x
    pos1.y = pos1.y - (1 / phys1.mass) * correction * normal.y
    pos2.x = pos2.x + (1 / phys2.mass) * correction * normal.x
    pos2.y = pos2.y + (1 / phys2.mass) * correction * normal.y
    
    -- ADDITIONAL: Clamp velocities to prevent re-penetration
    -- If objects are still moving toward each other after impulse, reduce that velocity component
    local rv_after = {x = vel2.vx - vel1.vx, y = vel2.vy - vel1.vy}
    local velAlongNormalAfter = rv_after.x * normal.x + rv_after.y * normal.y
    
    if velAlongNormalAfter < 0 then
        -- Still moving toward each other - apply additional damping
        local damping = 0.5
        vel1.vx = vel1.vx + damping * velAlongNormalAfter * normal.x
        vel1.vy = vel1.vy + damping * velAlongNormalAfter * normal.y
        vel2.vx = vel2.vx - damping * velAlongNormalAfter * normal.x
        vel2.vy = vel2.vy - damping * velAlongNormalAfter * normal.y
    end
end

local function applyProjectileDamage(projectileId, targetId)
    local proj = ECS.getComponent(projectileId, "Projectile")
    if not proj then return end

    local damage = proj.damage or 10
    -- Apply to Shield first, then Hull
    local shield = ECS.getComponent(targetId, "Shield")
    local hull = ECS.getComponent(targetId, "Hull")
    if shield and shield.current > 0 then
        -- Shield absorbed damage - create impact effect
        local pos = ECS.getComponent(projectileId, "Position")
        if pos then
            EntityHelpers.createShieldImpact(pos.x, pos.y, targetId)
        end
        
        local remaining = shield.current - damage
        shield.current = math.max(0, remaining)
        damage = math.max(0, -remaining)
        shield.regenTimer = shield.regenDelay or 0
    end
    if damage > 0 and hull then
        hull.current = math.max(0, hull.current - damage)
    end
    -- Also apply to Durability if present (asteroids and hull)
    local durability = ECS.getComponent(targetId, "Durability")
    if durability then
        durability.current = durability.current - damage
    end
    
    -- Trigger aggressive reaction if victim is AI
    EntityHelpers.notifyAIDamage(targetId, projectileId)
    -- If projectile is brittle, mark it for destruction
    if proj.brittle then
        local pDur = ECS.getComponent(projectileId, "Durability")
        if pDur then pDur.current = 0 end
    end
end

local PhysicsCollisionSystem = {
    name = "PhysicsCollisionSystem",

    update = function(dt)
        -- [QUADTREE INTEGRATED] Broad-phase collision pairing is now handled exclusively by Quadtree.
        -- This enables scalability to hundreds of entities. Legacy O(n^2) entity pairing is REMOVED.
        -- Quadtree covers collision candidates, all narrow-phase checks remain unchanged.

        -- First pass: update projectile owner immunity timers
        local projectiles = ECS.getEntitiesWith({"Projectile"})
        for _, projId in ipairs(projectiles) do
            local proj = ECS.getComponent(projId, "Projectile")
            if proj and proj.ownerImmunityTime and proj.ownerImmunityTime > 0 then
                proj.ownerImmunityTime = proj.ownerImmunityTime - dt
            end
        end

        -- Get all entities with physics colliders
        local physicsEntities = ECS.getEntitiesWith({"Position", "Velocity", "Physics", "Collidable"})
        
        -- Build quadtree for spatial partitioning
        local quadtree = Quadtree.create(
            Constants.world_min_x,
            Constants.world_min_y,
            Constants.world_width,
            Constants.world_height,
            0
        )
        
        -- Insert all entities into quadtree
        for _, entityId in ipairs(physicsEntities) do
            local pos = ECS.getComponent(entityId, "Position")
            local coll = ECS.getComponent(entityId, "Collidable")
            if pos and coll then
                Quadtree.insert(quadtree, entityId, pos, coll.radius)
            end
        end
        
        -- Calculate max velocity for CCD threshold (half bounding radius per frame is threshold)
        local maxVelocityThreshold = 50  -- u/s - if faster, use sub-frame checks
        
        -- Track processed pairs to avoid duplicate checks
        local processedPairs = {}
        
        -- Check collisions using quadtree (only check nearby entities)
        for _, entity1Id in ipairs(physicsEntities) do
            local pos1 = ECS.getComponent(entity1Id, "Position")
            local vel1 = ECS.getComponent(entity1Id, "Velocity")
            local phys1 = ECS.getComponent(entity1Id, "Physics")
            local coll1 = ECS.getComponent(entity1Id, "Collidable")
            local poly1 = ECS.getComponent(entity1Id, "PolygonShape")
            
            -- Skip item entities entirely for physics collision resolution. Items are collected
            -- by the magnet/collection systems and shouldn't physically collide with ships.
            if ECS.getComponent(entity1Id, "Item") then
                goto continue_entity1
            end

            if not (pos1 and vel1 and phys1 and coll1) then
                goto continue_entity1
            end
            
            -- Get nearby entities from quadtree (search radius = entity radius * 3 for swept checks)
            local searchRadius = coll1.radius * 3
            local nearbyEntities = Quadtree.getNearby(quadtree, pos1.x, pos1.y, searchRadius)
            
            -- Check collisions with nearby entities only
            for _, nearbyEntity in ipairs(nearbyEntities) do
                local entity2Id = nearbyEntity.id
                
                -- Skip self-collision
                if entity1Id == entity2Id then
                    goto continue_nearby
                end
                
                -- Skip if already processed this pair
                local pairKey1 = entity1Id < entity2Id and (entity1Id .. "_" .. entity2Id) or (entity2Id .. "_" .. entity1Id)
                if processedPairs[pairKey1] then
                    goto continue_nearby
                end
                processedPairs[pairKey1] = true
                
                local pos2 = ECS.getComponent(entity2Id, "Position")
                local vel2 = ECS.getComponent(entity2Id, "Velocity")
                local phys2 = ECS.getComponent(entity2Id, "Physics")
                local coll2 = ECS.getComponent(entity2Id, "Collidable")
                local poly2 = ECS.getComponent(entity2Id, "PolygonShape")
                
                if not (pos2 and vel2 and phys2 and coll2) then
                    goto continue_nearby
                end
                
                -- Use previous position for CCD if available, else use current position
                local prevPos1 = pos1.prevX and {x = pos1.prevX, y = pos1.prevY} or pos1
                local prevPos2 = pos2.prevX and {x = pos2.prevX, y = pos2.prevY} or pos2
                
                -- Calculate velocities for sub-frame detection
                local vel1Mag = math.sqrt(vel1.vx * vel1.vx + vel1.vy * vel1.vy)
                local vel2Mag = math.sqrt(vel2.vx * vel2.vx + vel2.vy * vel2.vy)
                local maxVel = math.max(vel1Mag, vel2Mag)
                
                -- Broad-phase: check swept bounding circles
                local bboxCheck1 = CollisionUtils.checkBoundingCircles(pos1.x, pos1.y, coll1.radius, pos2.x, pos2.y, coll2.radius)
                local bboxCheck2 = CollisionUtils.checkBoundingCircles(prevPos1.x, prevPos1.y, coll1.radius, pos2.x, pos2.y, coll2.radius)
                local bboxCheck3 = CollisionUtils.checkBoundingCircles(pos1.x, pos1.y, coll1.radius, prevPos2.x, prevPos2.y, coll2.radius)
                
                -- For very fast objects, also check mid-frame position
                local bboxCheckMid = false
                if maxVel > maxVelocityThreshold then
                    -- Check collision at mid-frame for fast-moving objects
                    local midPos1 = {x = pos1.x - vel1.vx * dt * 0.5, y = pos1.y - vel1.vy * dt * 0.5}
                    local midPos2 = {x = pos2.x - vel2.vx * dt * 0.5, y = pos2.y - vel2.vy * dt * 0.5}
                    bboxCheckMid = CollisionUtils.checkBoundingCircles(midPos1.x, midPos1.y, coll1.radius, midPos2.x, midPos2.y, coll2.radius)
                end
                
                if bboxCheck1 or bboxCheck2 or bboxCheck3 or bboxCheckMid then
                    local colliding = false
                    local normal = {x = 0, y = 1}
                    local depth = 0
                    
                    -- Narrow-phase collision detection
                    if poly1 and poly2 then
                            -- Both polygons - use SAT (expensive, so optimize)
                            -- Check SAT if: rotation changed, broad-phase hit in current frame, or occasionally
                            local rotationChanged = hasRotationChanged(poly1, poly2)
                            local shouldCheckSAT = rotationChanged or bboxCheck1 or (frameCounter % 2) == 0
                            
                            if shouldCheckSAT then
                                local isColliding, axis, overlap = checkPolygonPolygonCollisionSAT(pos1, poly1, pos2, poly2)
                                if isColliding and axis and overlap then
                                    normal = axis
                                    depth = overlap or 0
                                    colliding = true
                                end
                            end
                        elseif poly1 then
                            -- Entity1 is polygon, entity2 is circle (use CCD)
                            local ccdHit, impactPoint = checkSweptCirclePolygon(prevPos2, pos2, coll2.radius, pos1, poly1)
                            if ccdHit then
                                local collision = findCollisionNormal(pos1, poly1, impactPoint or pos2, coll2.radius)
                                normal = collision.normal
                                local dx = (impactPoint and (impactPoint.x - pos1.x) or (pos2.x - pos1.x))
                                local dy = (impactPoint and (impactPoint.y - pos1.y) or (pos2.y - pos1.y))
                                local dist = math.sqrt(dx * dx + dy * dy)
                                depth = math.max(0.1, coll2.radius + dist)
                                colliding = true
                                -- Swap normal direction for entity2 perspective
                                normal = {x = -normal.x, y = -normal.y}
                            end
                        elseif poly2 then
                            -- Entity2 is polygon, entity1 is circle (use CCD)
                            local ccdHit, impactPoint = checkSweptCirclePolygon(prevPos1, pos1, coll1.radius, pos2, poly2)
                            if ccdHit then
                                local collision = findCollisionNormal(pos2, poly2, impactPoint or pos1, coll1.radius)
                                normal = collision.normal
                                local dx = (impactPoint and (impactPoint.x - pos2.x) or (pos1.x - pos2.x))
                                local dy = (impactPoint and (impactPoint.y - pos2.y) or (pos1.y - pos2.y))
                                local dist = math.sqrt(dx * dx + dy * dy)
                                depth = math.max(0.1, coll1.radius + dist)
                                colliding = true
                            end
                        else
                            -- Both circles (use CCD)
                            local ccdHit = checkSweptCircleCircle(prevPos1, pos1, coll1.radius, pos2, coll2.radius)
                            local ccdHit2 = checkSweptCircleCircle(prevPos2, pos2, coll2.radius, pos1, coll1.radius)
                            
                            if ccdHit or ccdHit2 then
                                local dx = pos2.x - pos1.x
                                local dy = pos2.y - pos1.y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                if dist > 0 then
                                    normal = {x = dx / dist, y = dy / dist}
                                    depth = math.max(0.1, coll1.radius + coll2.radius - dist)
                                    colliding = true
                                end
                            end
                        end
                        
                    -- Resolve collision if detected
                    if colliding and vel1 and vel2 and phys1 and phys2 then
                        -- Check if either entity is a projectile or laser
                        local proj1 = ECS.getComponent(entity1Id, "Projectile")
                        local proj2 = ECS.getComponent(entity2Id, "Projectile")
                        local laser1 = ECS.getComponent(entity1Id, "LaserBeam")
                        local laser2 = ECS.getComponent(entity2Id, "LaserBeam")
                        
                        -- CRITICAL: Prevent projectiles/lasers from colliding with their owner ship
                        -- Check immunity timer to ensure projectile can't hit its own ship
                        if (proj1 and proj1.ownerId == entity2Id and proj1.ownerImmunityTime and proj1.ownerImmunityTime > 0) or
                           (proj2 and proj2.ownerId == entity1Id and proj2.ownerImmunityTime and proj2.ownerImmunityTime > 0) or
                           (laser1 and laser1.ownerId == entity2Id) or
                           (laser2 and laser2.ownerId == entity1Id) or
                           (proj1 and proj2) then
                            goto continue_nearby
                        end
                        
                        -- CRITICAL: Enemy projectiles should NOT collide with other enemies
                        -- They should only collide with the player and asteroids/wreckage
                        if (proj1 and not ECS.getComponent(proj1.ownerId, "ControlledBy") and ECS.getComponent(entity2Id, "AI")) or
                           (proj2 and not ECS.getComponent(proj2.ownerId, "ControlledBy") and ECS.getComponent(entity1Id, "AI")) then
                            goto continue_nearby
                        end
                        
                        -- Skip items colliding with player ship
                        -- Items should ignore player ship collisions
                        local item1 = ECS.getComponent(entity1Id, "Item")
                        local item2 = ECS.getComponent(entity2Id, "Item")
                        if (item1 and ECS.getComponent(entity2Id, "ControlledBy")) or
                           (item2 and ECS.getComponent(entity1Id, "ControlledBy")) then
                            goto continue_nearby
                        end
                        
                        -- CRITICAL: Missiles should ONLY collide with enemies (Hull component)
                        -- Skip missiles hitting asteroids, wreckages, or other non-enemy entities
                        if (proj1 and proj1.isMissile and not ECS.getComponent(entity2Id, "Hull")) or
                           (proj2 and proj2.isMissile and not ECS.getComponent(entity1Id, "Hull")) then
                            goto continue_nearby
                        end
                        
                        -- If either entity is a projectile, apply its damage to the other
                        if proj1 then
                            applyProjectileDamage(entity1Id, entity2Id)
                        end
                        if proj2 then
                            applyProjectileDamage(entity2Id, entity1Id)
                        end

                        resolveCollision(
                            {pos = pos1, vel = vel1, phys = phys1, angularVel = ECS.getComponent(entity1Id, "AngularVelocity"), rotMass = ECS.getComponent(entity1Id, "RotationalMass")},
                            {pos = pos2, vel = vel2, phys = phys2, angularVel = ECS.getComponent(entity2Id, "AngularVelocity"), rotMass = ECS.getComponent(entity2Id, "RotationalMass")},
                            normal,
                            depth
                        )
                    end
                end
                
                ::continue_nearby::
            end
            
            ::continue_entity1::
        end
        
        -- Increment frame counter for optimization
        frameCounter = frameCounter + 1
    end,
    
    getFrameCounter = function()
        return frameCounter
    end
}

return PhysicsCollisionSystem
