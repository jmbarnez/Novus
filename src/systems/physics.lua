-- Physics System - Handles all physics-related calculations
-- Updates entity positions based on velocity and acceleration

local ECS = require('src.ecs')

local PhysicsSystem = {
    name = "PhysicsSystem",
    priority = 2,

    update = function(dt)
        -- PHASE 0: Reset acceleration accumulators (so they don't accumulate across frames)
        local accelEntities = ECS.getEntitiesWith({"Acceleration"})
        for _, entityId in ipairs(accelEntities) do
            local acceleration = ECS.getComponent(entityId, "Acceleration")
            local projectile = ECS.getComponent(entityId, "Projectile")
            if acceleration then
                -- Don't reset acceleration for missiles - they need persistent acceleration
                if not (projectile and projectile.isMissile) then
                    acceleration.ax = 0
                    acceleration.ay = 0
                end
            end
        end
        
        -- PHASE 1: Convert accumulated forces to acceleration (F = ma -> a = F/m)
        local forceEntities = ECS.getEntitiesWith({"Force", "Physics", "Acceleration"})
        for _, entityId in ipairs(forceEntities) do
            local force = ECS.getComponent(entityId, "Force")
            local physics = ECS.getComponent(entityId, "Physics")
            local acceleration = ECS.getComponent(entityId, "Acceleration")
            
            if force and physics and acceleration then
                -- Convert force to acceleration: a = F/m
                acceleration.ax = acceleration.ax + (force.fx / physics.mass)
                acceleration.ay = acceleration.ay + (force.fy / physics.mass)
                
                -- Apply torque to angular velocity if entity has rotation
                if force.torque ~= 0 then
                    local angularVel = ECS.getComponent(entityId, "AngularVelocity")
                    local rotMass = ECS.getComponent(entityId, "RotationalMass")
                    if angularVel and rotMass then
                        -- Angular acceleration = torque / moment of inertia
                        angularVel.omega = angularVel.omega + (force.torque / rotMass.inertia) * dt
                    end
                end
                
                -- Reset force accumulators for next frame
                force.fx = 0
                force.fy = 0
                force.torque = 0
            end
        end
        
        -- PHASE 2: Get all entities with Position and Velocity (physics applies to all moving entities)
        local entities = ECS.getEntitiesWith({"Position", "Velocity"})

        for _, entityId in ipairs(entities) do
            local position = ECS.getComponent(entityId, "Position")
            local velocity = ECS.getComponent(entityId, "Velocity")
            if not (position and velocity) then goto continue_entity end
            local physics = ECS.getComponent(entityId, "Physics")
            local acceleration = ECS.getComponent(entityId, "Acceleration")

            -- Store previous position for CCD (Continuous Collision Detection)
            position.prevX = position.x
            position.prevY = position.y
            
            -- Store previous rotation for rotated object CCD
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            if polygonShape then
                polygonShape.prevRotation = polygonShape.rotation
            end

            -- Apply acceleration to velocity
            if acceleration then
                velocity.vx = velocity.vx + acceleration.ax * dt
                velocity.vy = velocity.vy + acceleration.ay * dt
            end

            -- Apply friction (use default values if no Physics component)
            if physics then
                velocity.vx = velocity.vx * physics.friction
                velocity.vy = velocity.vy * physics.friction
            end

            -- Update position based on velocity
            position.x = position.x + velocity.vx * dt
            position.y = position.y + velocity.vy * dt
            
            -- Debug log for projectiles
            local proj = ECS.getComponent(entityId, "Projectile")
            if proj and velocity then
                if velocity.vx ~= 0 or velocity.vy ~= 0 then
                    -- Projectile moved to new position
                end
            end
            ::continue_entity::
        end
        
        -- Update angular velocity for entities with rotation
        local angularEntities = ECS.getEntitiesWith({"AngularVelocity", "PolygonShape"})
        for _, entityId in ipairs(angularEntities) do
            local angularVelocity = ECS.getComponent(entityId, "AngularVelocity")
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            local physics = ECS.getComponent(entityId, "Physics")
            if not (angularVelocity and polygonShape) then goto continue_angular end
            
            -- Apply angular damping (rotational friction)
            if physics and physics.angularDamping then
                angularVelocity.omega = angularVelocity.omega * physics.angularDamping
            end
            
            -- Update rotation
            polygonShape.rotation = polygonShape.rotation + (angularVelocity.omega or 0) * dt
            ::continue_angular::
        end

        -- Shield regeneration (per-entity)
        local shieldEntities = ECS.getEntitiesWith({"Shield"})
        for _, entityId in ipairs(shieldEntities) do
            local shield = ECS.getComponent(entityId, "Shield")
            if not shield then goto continue_shield end
            
            -- Count down regen delay
            if shield.regenTimer and shield.regenTimer > 0 then
                shield.regenTimer = shield.regenTimer - dt
            else
                if shield.regen and shield.regen > 0 and shield.current < shield.max then
                    -- Check if we have energy to regenerate shields
                    local energy = ECS.getComponent(entityId, "Energy")
                    local EnergySystem = require('src.systems.energy')
                    
                    if energy and EnergySystem.consume(energy, EnergySystem.CONSUMPTION.shield_regen * dt) then
                        -- Shield regen slows down as it approaches max
                        -- Scale factor: 1.0 at 0%, ~0.3 at 90%, ~0.1 at 99%
                        local shieldPercent = shield.current / shield.max
                        local slowdownFactor = 1.0 - (shieldPercent * shieldPercent * 0.9)  -- Quadratic slowdown
                        
                        local regenAmount = shield.regen * dt * slowdownFactor
                        shield.current = math.min(shield.max, shield.current + regenAmount)
                    end
                end
            end
            ::continue_shield::
        end
    end,

    takeDamage = function(entityId, amount)
        -- Apply damage to shield first, then hull
        local shield = ECS.getComponent(entityId, "Shield")
        local hull = ECS.getComponent(entityId, "Hull")
        local damage = amount
        if shield and shield.current > 0 then
            local remaining = shield.current - damage
            shield.current = math.max(0, remaining)
            damage = math.max(0, -remaining)
            shield.regenTimer = shield.regenDelay or 0
        end
        if damage > 0 and hull then
            hull.current = math.max(0, hull.current - damage)
        end
    end
}

return PhysicsSystem