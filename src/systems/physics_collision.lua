-- Physics Collision System - Universal collision handling for all physics entities
-- Handles collisions between any entities with Position, Velocity, Physics, and Collidable components


local ECS = require('src.ecs')
local Constants = require('src.constants')
local Quadtree = require('src.systems.quadtree')
local CollisionUtils = require('src.collision_utils')
local EntityHelpers = require('src.entity_helpers')
-- sound handled in effects module

-- Localize hot math functions to reduce table lookups in hot paths
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_cos = math.cos
local math_sin = math.sin

-- Shared quadtree instance reused each frame to reduce allocations
local sharedQuadtree = nil

-- Split responsibilities into modules
local CCD = require('src.systems.collision_ccd')
local SAT = require('src.systems.collision_sat')
local Resolver = require('src.systems.collision_resolver')
local Effects = require('src.systems.collision_effects')

-- Frame counter for optimization
local frameCounter = 0

-- audio and damage effects are handled in `src/systems/collision_effects.lua`

local function hasRotationChanged(poly1, poly2, rotationThreshold)
    rotationThreshold = rotationThreshold or 0.1  -- ~5.7 degrees
    local rot1Changed = poly1 and math_abs(poly1.rotation - (poly1.prevRotation or 0)) > rotationThreshold or false
    local rot2Changed = poly2 and math_abs(poly2.rotation - (poly2.prevRotation or 0)) > rotationThreshold or false
    return rot1Changed or rot2Changed
end

-- projectile resolver moved to `src/systems/collision_resolver.lua`

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
        local dist = math_sqrt(fx * fx + fy * fy)
        return dist < minDist, 0  -- Return collision flag and time of impact
    end
    
    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then
        return false, 1  -- No intersection
    end
    
    discriminant = math_sqrt(discriminant)
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
    local cos = math_cos(rotation)
    local sin = math_sin(rotation)
    -- Transform vertices to world space
    local transformedVertices = {}
    for i = 1, #vertices do
        local v = vertices[i]
        local rx = v.x * cos - v.y * sin
        local ry = v.x * sin + v.y * cos
        transformedVertices[i] = {x = polygonPos.x + rx, y = polygonPos.y + ry}
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
                t = math_max(0, math_min(1, t))
                local px = oldPos.x + t * sweepDx
                local py = oldPos.y + t * sweepDy
                local edgeDot2 = (px - v1.x) * edgeDx + (py - v1.y) * edgeDy
                local s = edgeDot2 / (edgeLen * edgeLen)
                s = math_max(0, math_min(1, s))
                local ex = v1.x + s * edgeDx
                local ey = v1.y + s * edgeDy
                local dx = px - ex
                local dy = py - ey
                local dist = math_sqrt(dx * dx + dy * dy)
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

-- SAT polygon helpers moved to `src/systems/collision_sat.lua`

-- Collision normal finder moved to `src/systems/collision_sat.lua`

-- collision resolver moved to `src/systems/collision_resolver.lua`

-- damage and SFX moved to `src/systems/collision_effects.lua`

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
        
        -- Build/reuse quadtree for spatial partitioning
        if not sharedQuadtree then
            sharedQuadtree = Quadtree.create(
                Constants.world_min_x,
                Constants.world_min_y,
                Constants.world_width,
                Constants.world_height,
                0
            )
        else
            -- If Quadtree provides a clear function, use it to reset state; otherwise recreate
            if Quadtree.clear then
                Quadtree.clear(sharedQuadtree)
            else
                sharedQuadtree = Quadtree.create(
                    Constants.world_min_x,
                    Constants.world_min_y,
                    Constants.world_width,
                    Constants.world_height,
                    0
                )
            end
        end

        local quadtree = sharedQuadtree

        -- Insert all entities into quadtree
        for i = 1, #physicsEntities do
            local entityId = physicsEntities[i]
            local pos = ECS.getComponent(entityId, "Position")
            local coll = ECS.getComponent(entityId, "Collidable")
            if pos and coll then
                Quadtree.insert(quadtree, entityId, pos, coll.radius)
            end
        end
        
        -- Calculate max velocity for CCD threshold (half bounding radius per frame is threshold)
        local maxVelocityThreshold = 50  -- u/s - if faster, use sub-frame checks
        
        -- Track processed pairs to avoid duplicate checks (use nested table to avoid string allocations)
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
                local a = entity1Id
                local b = entity2Id
                if a > b then a, b = b, a end
                if processedPairs[a] and processedPairs[a][b] then
                    goto continue_nearby
                end
                processedPairs[a] = processedPairs[a] or {}
                processedPairs[a][b] = true
                
                local pos2 = ECS.getComponent(entity2Id, "Position")
                local vel2 = ECS.getComponent(entity2Id, "Velocity")
                local phys2 = ECS.getComponent(entity2Id, "Physics")
                local coll2 = ECS.getComponent(entity2Id, "Collidable")
                local poly2 = ECS.getComponent(entity2Id, "PolygonShape")
                -- Determine shape type: prefer explicit polygon if present; otherwise treat as circle
                local isPoly1 = (poly1 ~= nil)
                local isPoly2 = (poly2 ~= nil)
                
                if not (pos2 and vel2 and phys2 and coll2) then
                    goto continue_nearby
                end
                
                -- Use previous position for CCD if available, else use current position
                local prevPos1 = pos1.prevX and {x = pos1.prevX, y = pos1.prevY} or pos1
                local prevPos2 = pos2.prevX and {x = pos2.prevX, y = pos2.prevY} or pos2
                
                -- Calculate velocities for sub-frame detection
                local vel1Mag = math_sqrt(vel1.vx * vel1.vx + vel1.vy * vel1.vy)
                local vel2Mag = math_sqrt(vel2.vx * vel2.vx + vel2.vy * vel2.vy)
                local maxVel = math_max(vel1Mag, vel2Mag)
                
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
                    
                    -- Narrow-phase collision detection (polygon-first if present, else circle)
                        if isPoly1 and isPoly2 then
                            -- Both polygons - use SAT (expensive, so optimize)
                            -- Check SAT if: rotation changed, broad-phase hit in current frame, or occasionally
                            local rotationChanged = hasRotationChanged(poly1, poly2)
                            local shouldCheckSAT = rotationChanged or bboxCheck1 or (frameCounter % 2) == 0
                            
                            if shouldCheckSAT then
                                local isColliding, axis, overlap = SAT.checkPolygonPolygonCollisionSAT(pos1, poly1, pos2, poly2)
                                if isColliding and axis and overlap then
                                    normal = axis
                                    depth = overlap or 0
                                    colliding = true
                                end
                            end
                        elseif isPoly1 then
                            -- Entity1 is polygon, entity2 is circle (use CCD)
                            local ccdHit, impactPoint = CCD.checkSweptCirclePolygon(prevPos2, pos2, coll2.radius, pos1, poly1)
                            if ccdHit then
                                local collision = SAT.findCollisionNormal(pos1, poly1, impactPoint or pos2, coll2.radius)
                                normal = collision.normal
                                local dx = (impactPoint and (impactPoint.x - pos1.x) or (pos2.x - pos1.x))
                                local dy = (impactPoint and (impactPoint.y - pos1.y) or (pos2.y - pos1.y))
                                local dist = math_sqrt(dx * dx + dy * dy)
                                -- depth is overlap: radius - distance from circle center to closest point
                                depth = math_max(0.1, coll2.radius - dist)
                                colliding = true
                                -- Swap normal direction for entity2 perspective
                                normal = {x = -normal.x, y = -normal.y}
                            end
                        elseif isPoly2 then
                            -- Entity2 is polygon, entity1 is circle (use CCD)
                            local ccdHit, impactPoint = CCD.checkSweptCirclePolygon(prevPos1, pos1, coll1.radius, pos2, poly2)
                            if ccdHit then
                                local collision = SAT.findCollisionNormal(pos2, poly2, impactPoint or pos1, coll1.radius)
                                normal = collision.normal
                                local dx = (impactPoint and (impactPoint.x - pos2.x) or (pos1.x - pos2.x))
                                local dy = (impactPoint and (impactPoint.y - pos2.y) or (pos1.y - pos2.y))
                                local dist = math_sqrt(dx * dx + dy * dy)
                                -- depth is overlap: radius - distance from circle center to closest point
                                depth = math_max(0.1, coll1.radius - dist)
                                colliding = true
                            end
                        else
                            -- Both circles (use CCD)
                            local ccdHit = CCD.checkSweptCircleCircle(prevPos1, pos1, coll1.radius, pos2, coll2.radius)
                            local ccdHit2 = CCD.checkSweptCircleCircle(prevPos2, pos2, coll2.radius, pos1, coll1.radius)
                            
                            if ccdHit or ccdHit2 then
                                local dx = pos2.x - pos1.x
                                local dy = pos2.y - pos1.y
                                local dist = math_sqrt(dx * dx + dy * dy)
                                if dist > 0 then
                                    normal = {x = dx / dist, y = dy / dist}
                                    depth = math_max(0.1, coll1.radius + coll2.radius - dist)
                                    colliding = true
                                end
                            end
                        end
                        
                    -- Resolve collision if detected
                    if colliding and vel1 and vel2 and phys1 and phys2 then
                        -- Check for shield collision effects
                        local shield1 = ECS.getComponent(entity1Id, "Shield")
                        local shield2 = ECS.getComponent(entity2Id, "Shield")

                        -- Create shield impact effects if either entity has an active shield
                        if (shield1 and shield1.current > 0) or (shield2 and shield2.current > 0) then
                            -- Calculate collision point (approximate as midpoint)
                            local collisionX = (pos1.x + pos2.x) / 2
                            local collisionY = (pos1.y + pos2.y) / 2

                            -- Create impact effect for entity1 if it has shield
                            if shield1 and shield1.current > 0 then
                                EntityHelpers.createShieldImpact(collisionX, collisionY, entity1Id)
                            end

                            -- Create impact effect for entity2 if it has shield
                            if shield2 and shield2.current > 0 then
                                EntityHelpers.createShieldImpact(collisionX, collisionY, entity2Id)
                            end
                        end

                        -- Check if either entity is a projectile or laser
                        local proj1 = ECS.getComponent(entity1Id, "Projectile")
                        local proj2 = ECS.getComponent(entity2Id, "Projectile")
                        local laser1 = ECS.getComponent(entity1Id, "LaserBeam")
                        local laser2 = ECS.getComponent(entity2Id, "LaserBeam")
                        
                        -- Only prevent projectiles/lasers from immediately hitting their owner ship (self-damage prevention)
                        if (proj1 and proj1.ownerId == entity2Id and proj1.ownerImmunityTime and proj1.ownerImmunityTime > 0) or
                           (proj2 and proj2.ownerId == entity1Id and proj2.ownerImmunityTime and proj2.ownerImmunityTime > 0) or
                           (laser1 and laser1.ownerId == entity2Id) or
                           (laser2 and laser2.ownerId == entity1Id) then
                            goto continue_nearby
                        end
                        
                        -- Skip items colliding with player ship (collection mechanic, not damage-related)
                        local item1 = ECS.getComponent(entity1Id, "Item")
                        local item2 = ECS.getComponent(entity2Id, "Item")
                        if (item1 and ECS.getComponent(entity2Id, "ControlledBy")) or
                           (item2 and ECS.getComponent(entity1Id, "ControlledBy")) then
                            goto continue_nearby
                        end
                        
                        -- Apply projectile damage (no additional filters - projectiles can damage anything)
                        if proj1 then
                            Effects.applyProjectileDamage(entity1Id, entity2Id)
                            local collisionX = (pos1.x + pos2.x) / 2
                            local collisionY = (pos1.y + pos2.y) / 2
                            Effects.playProjectileImpactSfx(proj1, entity2Id, collisionX, collisionY)
                            -- If this projectile is a missile, ensure it explodes on any collision
                            if proj1.isMissile then
                                local pDur = ECS.getComponent(entity1Id, "Durability")
                                if pDur then pDur.current = 0 end
                            end
                        end
                        if proj2 then
                            Effects.applyProjectileDamage(entity2Id, entity1Id)
                            local collisionX = (pos1.x + pos2.x) / 2
                            local collisionY = (pos1.y + pos2.y) / 2
                            Effects.playProjectileImpactSfx(proj2, entity1Id, collisionX, collisionY)
                            -- If this projectile is a missile, ensure it explodes on any collision
                            if proj2.isMissile then
                                local pDur = ECS.getComponent(entity2Id, "Durability")
                                if pDur then pDur.current = 0 end
                            end
                        end

                        -- If either side is a projectile, use specialized resolver so projectiles bounce reliably
                        if proj1 or proj2 then
                            if proj1 then
                                Resolver.resolveProjectileCollision(entity1Id, entity2Id, normal, depth, ECS)
                            else
                                Resolver.resolveProjectileCollision(entity2Id, entity1Id, normal, depth, ECS)
                            end
                        else
                            Resolver.resolveCollision(
                                {pos = pos1, vel = vel1, phys = phys1, angularVel = ECS.getComponent(entity1Id, "AngularVelocity"), rotMass = ECS.getComponent(entity1Id, "RotationalMass")},
                                {pos = pos2, vel = vel2, phys = phys2, angularVel = ECS.getComponent(entity2Id, "AngularVelocity"), rotMass = ECS.getComponent(entity2Id, "RotationalMass")},
                                normal,
                                depth
                            )
                        end
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
