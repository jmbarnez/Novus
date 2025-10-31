-- Projectile System - Handles projectile collisions and effects

local ECS = require('src.ecs')
local Components = require('src.components')
local EntityHelpers = require('src.entity_helpers')
local CollisionUtils = require('src.collision_utils')
local DebrisSystem = require('src.systems.debris')

local ProjectileSystem = {
    name = "ProjectileSystem",
    priority = 5
}

function ProjectileSystem.update(dt)
    local projectiles = ECS.getEntitiesWith({"Projectile", "Position", "Collidable"})
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Collidable", "Durability"})
    local wreckages = ECS.getEntitiesWith({"Wreckage", "Position", "Collidable", "Durability"})
    local stations = ECS.getEntitiesWith({"Station", "Position", "Collidable"}) -- Stations have Station component
    local enemies = ECS.getEntitiesWith({"Hull", "Position", "Collidable"}) -- Enemies have Hull component

    for _, projId in ipairs(projectiles) do
        local projPos = ECS.getComponent(projId, "Position")
        local projColl = ECS.getComponent(projId, "Collidable")
        local projectile = ECS.getComponent(projId, "Projectile")
        if not (projPos and projColl) then goto continue_projectile end

        -- Update projectile lifetime and check for expiration
        local lifetime = ECS.getComponent(projId, "ProjectileLifetime")
        if lifetime then
            lifetime.age = lifetime.age + dt
            if lifetime.age >= lifetime.maxAge then
                -- Projectile exceeded max age - shatter it
                local projDur = ECS.getComponent(projId, "Durability")
                if projDur then projDur.current = 0 end
            end
        end

        -- Asteroid collision: all projectiles damage asteroids
        for _, asteroidId in ipairs(asteroids) do
            local asteroidPos = ECS.getComponent(asteroidId, "Position")
            local asteroidColl = ECS.getComponent(asteroidId, "Collidable")
            if not (asteroidPos and asteroidColl) then goto continue_asteroid end
            
            local dx = asteroidPos.x - projPos.x
            local dy = asteroidPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = asteroidColl.radius + projColl.radius
            
            if distSq < radii * radii then
                if projectile and projectile.ownerId == asteroidId then goto continue_asteroid end
                
                -- Apply damage to asteroid
                if projectile then
                    local durability = ECS.getComponent(asteroidId, "Durability")
                    if durability then
                        local damage = projectile.damage or 10
                        local damageToApply = damage
                        
                        -- Turret module projectiles deal 4x damage to asteroids
                        if projectile.weaponModule or projectile.weaponType then
                            damageToApply = damage * 4.0
                        else
                            damageToApply = damage * 0.1
                        end
                        
                        durability.current = math.max(0, durability.current - damageToApply)
                        
                        -- Track who damaged this asteroid for XP/loot purposes
                        if projectile.ownerId then
                            local weaponModule = projectile.weaponModule or projectile.weaponType or nil
                            EntityHelpers.recordLastDamager(asteroidId, projectile.ownerId, weaponModule)
                        end
                    end
                end
                
                -- Don't let projectiles pass through asteroids
                local shouldDestroy = false
                if projectile and projectile.brittle then
                    -- Brittle projectiles (cannon balls, railgun slugs) shatter
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                    shouldDestroy = true
                end
                -- Non-brittle projectiles (missiles) also destroy on impact
                if projectile and projectile.isMissile then
                    -- Create explosion effect on impact
                    DebrisSystem.createDebris(projPos.x, projPos.y, 20, {1.0, 0.5, 0.1, 1}) -- Orange-red explosion
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                    shouldDestroy = true
                end
                
                if shouldDestroy then
                    break  -- Break for brittle/missile projectiles
                end
                -- Non-brittle, non-missile projectiles bounce (handled by physics system)
            end
            ::continue_asteroid::
        end

        -- Wreckage collision: all projectiles damage wreckage
        for _, wreckId in ipairs(wreckages) do
            local wreckPos = ECS.getComponent(wreckId, "Position")
            local wreckColl = ECS.getComponent(wreckId, "Collidable")
            if not (wreckPos and wreckColl) then goto continue_wreckage end
            
            local dx = wreckPos.x - projPos.x
            local dy = wreckPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = wreckColl.radius + projColl.radius
            
            if distSq < radii * radii then
                if projectile and projectile.ownerId == wreckId then goto continue_wreckage end
                
                -- Apply damage to wreckage
                if projectile then
                    local durability = ECS.getComponent(wreckId, "Durability")
                    if durability then
                        local damage = projectile.damage or 10
                        local damageToApply = damage
                        
                        -- Turret module projectiles deal 4x damage to wreckage
                        if projectile.weaponModule or projectile.weaponType then
                            damageToApply = damage * 4.0
                        else
                            damageToApply = damage * 0.1
                        end
                        
                        durability.current = math.max(0, durability.current - damageToApply)
                        
                        -- Track who damaged this wreckage for XP/loot purposes
                        if projectile.ownerId then
                            local weaponModule = projectile.weaponModule or projectile.weaponType or nil
                            EntityHelpers.recordLastDamager(wreckId, projectile.ownerId, weaponModule)
                        end
                    end
                end
                
                -- Non-laser projectiles can't pass through wreckage
                local shouldDestroy = false
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                    shouldDestroy = true
                end
                if projectile and projectile.isMissile then
                    -- Create explosion effect on impact
                    DebrisSystem.createDebris(projPos.x, projPos.y, 20, {1.0, 0.5, 0.1, 1}) -- Orange-red explosion
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                    shouldDestroy = true
                end
                
                if shouldDestroy then
                    break  -- Break for brittle/missile projectiles
                end
                -- Non-brittle, non-missile projectiles bounce (handled by physics system)
            end
            ::continue_wreckage::
        end

        -- Station collision: projectiles can't pass through stations
        for _, stationId in ipairs(stations) do
            local stationPos = ECS.getComponent(stationId, "Position")
            local stationColl = ECS.getComponent(stationId, "Collidable")
            if not (stationPos and stationColl) then goto continue_station end
            
            -- Check if station has polygon shape
            local stationPoly = ECS.getComponent(stationId, "PolygonShape")
            local collisionDetected = false
            
            if stationPoly then
                -- Use polygon collision detection for accurate collision
                local stationWorldPoly = CollisionUtils.transformPolygon(stationPos, stationPoly)
                local projPolyShape = ECS.getComponent(projId, "PolygonShape")
                
                if projPolyShape then
                    -- Projectile is also a polygon - check polygon vs polygon
                    local projWorldPoly = CollisionUtils.transformPolygon(projPos, projPolyShape)
                    if CollisionUtils.checkPolygonPolygonCollision(stationWorldPoly, projWorldPoly) then
                        collisionDetected = true
                    end
                else
                    -- Projectile is a circle - check polygon vs circle
                    if CollisionUtils.checkPolygonCircleCollision(stationWorldPoly, projPos.x, projPos.y, projColl.radius) then
                        collisionDetected = true
                    end
                end
            else
                -- Fallback to circle collision
                local dx = stationPos.x - projPos.x
                local dy = stationPos.y - projPos.y
                local distSq = dx * dx + dy * dy
                local radii = stationColl.radius + projColl.radius
                if distSq < radii * radii then
                    collisionDetected = true
                end
            end
            
            if collisionDetected then
                if projectile and projectile.ownerId == stationId then goto continue_station end
                
                -- Projectiles can't pass through stations - destroy on impact
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                if projectile and projectile.isMissile then
                    -- Create explosion effect on impact
                    DebrisSystem.createDebris(projPos.x, projPos.y, 20, {1.0, 0.5, 0.1, 1}) -- Orange-red explosion
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                
                -- Non-brittle, non-missile projectiles bounce (handled by physics system)
                if projectile and not projectile.brittle and not projectile.isMissile then
                    -- Let physics system handle the bounce - don't destroy
                else
                    break  -- Only break for brittle/missile projectiles
                end
            end
            ::continue_station::
        end

        -- Enemy damage: all projectiles except mining/salvage/combat lasers hit enemies
        for _, enemyId in ipairs(enemies) do
            if projectile and projectile.ownerId == enemyId then goto continue_enemy end -- Don't hit self
            
            local enemyPos = ECS.getComponent(enemyId, "Position")
            local enemyColl = ECS.getComponent(enemyId, "Collidable")
            if not (enemyPos and enemyColl) then goto continue_enemy end
            
            local dx = enemyPos.x - projPos.x
            local dy = enemyPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = enemyColl.radius + projColl.radius
            
            if distSq < radii * radii then
                -- All projectiles hit enemies (brittle shatter, missiles destroy, bouncy continue)
                -- Only brittle/missile projectiles get destroyed after dealing damage
                local shouldDestroy = projectile.isMissile or projectile.brittle
                
                if projectile then
                    local shield = ECS.getComponent(enemyId, "Shield")
                    local hull = ECS.getComponent(enemyId, "Hull")
                    local damage = projectile.damage or 10
                    
                    -- Apply damage to shield first, then hull
                    if shield and shield.current > 0 then
                        -- Shield absorbed damage - create impact effect
                        EntityHelpers.createShieldImpact(projPos.x, projPos.y, enemyId)
                        
                        local remaining = shield.current - damage
                        shield.current = math.max(0, remaining)
                        damage = math.max(0, -remaining)
                        shield.regenTimer = shield.regenDelay or 0
                    end
                    
                    -- Apply remaining damage to hull
                    if damage > 0 and hull then
                        hull.current = math.max(0, hull.current - damage)
                    end
                    
                    -- Notify AI of damage so behavior trees can react (aggression)
                    local shooter = projectile.ownerId
                    EntityHelpers.notifyAIDamage(enemyId, shooter)
                    
                    -- Destroy missile on impact
                    if projectile.isMissile then
                        -- Create explosion effect on impact
                        DebrisSystem.createDebris(projPos.x, projPos.y, 20, {1.0, 0.5, 0.1, 1}) -- Orange-red explosion
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                    
                    -- Destroy brittle projectiles on impact
                    if projectile.brittle then
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                    
                    -- Only break if projectile was destroyed (brittle or missile)
                    if shouldDestroy then
                        break
                    end
                    -- Otherwise let bouncy projectiles continue (physics handles the bounce)
                end
            end
            ::continue_enemy::
        end

        ::continue_projectile::
    end
end

return ProjectileSystem
