---@diagnostic disable: undefined-global
-- Trail System - Manages particle trails for visual effects
-- Creates and updates trail particles behind moving entities

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')

-- Track particle count efficiently (outside the table definition)
local particleCount = 0

local TrailSystem = {
    name = "TrailSystem",
    priority = 8,
    update = function(dt)
        -- Update existing trail particles and count them
        local trailEntities = ECS.getEntitiesWith({"TrailParticle"})
        local aliveParticles = 0

        for _, entityId in ipairs(trailEntities) do
            local particle = ECS.getComponent(entityId, "TrailParticle")

            -- Update particle position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt

            -- Update lifetime
            particle.life = particle.life - dt

            -- Remove dead particles
            if particle.life <= 0 then
                ECS.destroyEntity(entityId)
            else
                aliveParticles = aliveParticles + 1
            end
        end

        -- Update particle count
        particleCount = aliveParticles

        -- Emit new particles from trail emitters
        local emitterEntities = ECS.getEntitiesWith({"Position", "Velocity", "TrailEmitter", "Renderable"})

        for _, entityId in ipairs(emitterEntities) do
            local position = ECS.getComponent(entityId, "Position")
            local velocity = ECS.getComponent(entityId, "Velocity")
            local emitter = ECS.getComponent(entityId, "TrailEmitter")
            local renderable = ECS.getComponent(entityId, "Renderable")

            -- Calculate ship speed
            local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)

            -- Only emit if moving (minimum speed threshold)
            if speed > 10 then
                emitter.lastEmit = emitter.lastEmit + dt

                -- Check if we should emit a particle
                if emitter.lastEmit >= (1.0 / emitter.emitRate) then
                    emitter.lastEmit = 0

                    -- Use efficient particle count
                    if particleCount < emitter.maxParticles then
                        -- Calculate emission position (behind the ship)
                        local angle = math.atan2(velocity.vy, velocity.vx)
                        local offsetDistance = renderable.radius + 2 -- Distance behind ship
                        local emitX = position.x - math.cos(angle) * offsetDistance
                        local emitY = position.y - math.sin(angle) * offsetDistance

                        -- Add some random spread
                        local spread = (math.random() - 0.5) * emitter.spreadAngle
                        local emitAngle = angle + spread

                        -- Calculate particle velocity (opposite to ship direction with some randomness)
                        local particleSpeed = speed * emitter.speedMultiplier
                        local particleVx = -math.cos(emitAngle) * particleSpeed + (math.random() - 0.5) * 20
                        local particleVy = -math.sin(emitAngle) * particleSpeed + (math.random() - 0.5) * 20

                        -- Create particle entity
                        local particleId = ECS.createEntity()
                        ECS.addComponent(particleId, "TrailParticle",
                            Components.TrailParticle(
                                emitX, emitY, -- position
                                particleVx, particleVy, -- velocity
                                emitter.particleLife, -- lifetime
                                Constants.trail_particle_size_min + math.random() * (Constants.trail_particle_size_max - Constants.trail_particle_size_min), -- size (0.5-1.0)
                                {0.3, 0.7, 1.0, 0.9} -- blue-white color
                            )
                        )
                        
                        -- Increment particle count
                        particleCount = particleCount + 1
                    end
                end
            end
        end
    end
}

return TrailSystem
