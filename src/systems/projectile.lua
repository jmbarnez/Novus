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
-- NOTE: collision resolution should be handled centrally by
-- `PhysicsCollisionSystem`. Projectile-specific bounce/velocity tweaks
-- were removed so the physics system remains authoritative.

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

        -- Defer collision handling to the centralized physics collision system.
        -- ProjectileSystem no longer performs narrow-phase checks.
        goto continue_projectile

        -- Collision handling is now centralized in PhysicsCollisionSystem.
        -- All narrow-phase checks and damage application happen there.

        ::continue_projectile::
    end
end

return ProjectileSystem
