-- Projectile System - Handles projectile collisions and effects

local ECS = require('src.ecs')
local Components = require('src.components')

local ProjectileSystem = {
    name = "ProjectileSystem",
    priority = 5
}

function ProjectileSystem.update(dt)
    local projectiles = ECS.getEntitiesWith({"Projectile", "Position", "Collidable"})
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Collidable", "Durability"})
    local wreckages = ECS.getEntitiesWith({"Wreckage", "Position", "Collidable", "Durability"})
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

        -- Asteroid collision: all non-laser projectiles bounce or break on asteroids
        for _, asteroidId in ipairs(asteroids) do
            local asteroidPos = ECS.getComponent(asteroidId, "Position")
            local asteroidColl = ECS.getComponent(asteroidId, "Collidable")
            if not (asteroidPos and asteroidColl) then goto continue_asteroid end
            
            local dx = asteroidPos.x - projPos.x
            local dy = asteroidPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = asteroidColl.radius + projColl.radius
            
            if distSq < radii * radii then
                -- Don't let projectiles pass through asteroids
                if projectile and projectile.brittle then
                    -- Brittle projectiles (cannon balls) shatter
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                -- Non-brittle projectiles (missiles) also destroy on impact
                if projectile and projectile.isMissile then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                break
            end
            ::continue_asteroid::
        end

        -- Wreckage collision: projectiles can't pass through
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
                
                -- Non-laser projectiles can't pass through wreckage
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                if projectile and projectile.isMissile then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                
                break
            end
            ::continue_wreckage::
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
                -- Only missiles and cannons hit enemies (not lasers - they're handled by their modules)
                if projectile and (projectile.isMissile or projectile.brittle) then
                    local shield = ECS.getComponent(enemyId, "Shield")
                    local hull = ECS.getComponent(enemyId, "Hull")
                    local damage = projectile.damage or 10
                    
                    -- Apply damage to shield first, then hull
                    if shield and shield.current > 0 then
                        -- Shield absorbed damage - create impact effect
                        local ShieldImpactSystem = ECS.getSystem("ShieldImpactSystem")
                        if ShieldImpactSystem and ShieldImpactSystem.createImpact then
                            ShieldImpactSystem.createImpact(projPos.x, projPos.y, enemyId)
                        end
                        
                        local remaining = shield.current - damage
                        shield.current = math.max(0, remaining)
                        damage = math.max(0, -remaining)
                        shield.regenTimer = shield.regenDelay or 0
                    end
                    
                    -- Apply remaining damage to hull
                    if damage > 0 and hull then
                        hull.current = math.max(0, hull.current - damage)
                    end
                    
                    -- Trigger aggressive reaction if victim is AI
                    local AISystem = ECS.getSystem("AISystem")
                    if AISystem and AISystem.triggerAggressiveReaction then
                        AISystem.triggerAggressiveReaction(enemyId, projId)
                    end
                    
                    -- Destroy missile on impact
                    if projectile.isMissile then
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                    
                    -- Destroy brittle projectiles on impact
                    if projectile.brittle then
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                end
                break
            end
            ::continue_enemy::
        end

        ::continue_projectile::
    end
end

return ProjectileSystem
