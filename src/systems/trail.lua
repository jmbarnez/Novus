---@diagnostic disable: undefined-global
-- Trail System - Manages particle trails for visual effects
-- Creates and updates trail particles behind moving entities

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local EntityPool = require('src.entity_pool')
local HotkeyConfig = require('src.hotkey_config')

-- Track particle count efficiently (outside the table definition)
local particleCount = 0
-- Track active particle counts per-emitter to avoid global contention and enable continuous streams
local emitterActiveCounts = {}

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

            -- Remove dead particles (return to pool instead of destroying)
            if particle.life <= 0 then
                -- Decrement owner emitter count if present
                local owner = particle._owner
                if owner and emitterActiveCounts[owner] then
                    emitterActiveCounts[owner] = math.max(0, emitterActiveCounts[owner] - 1)
                end
                EntityPool.release("trail_particle", entityId)
            else
                aliveParticles = aliveParticles + 1
            end
        end

        -- Update particle count
        particleCount = aliveParticles

        -- Emit new particles from trail emitters (also attach default emitter to ships without one)
        local emitterEntities = ECS.getEntitiesWith({"Position", "Velocity", "Renderable"})

        for _, entityId in ipairs(emitterEntities) do
            local position = ECS.getComponent(entityId, "Position")
            local velocity = ECS.getComponent(entityId, "Velocity")
            local emitter = ECS.getComponent(entityId, "TrailEmitter")
            local renderable = ECS.getComponent(entityId, "Renderable")

            -- If this entity has no explicit TrailEmitter but looks like a ship (Hull), attach a default emitter so all ships get trails
            local localEmitter = emitter
            local isShip = ECS.hasComponent(entityId, "Hull") or ECS.hasComponent(entityId, "Station") or ECS.hasComponent(entityId, "StationDetails")
            if not localEmitter and isShip then
                -- Default emitter settings (matches player feel); enemy color will be set below
                localEmitter = {
                    emitRate = 60,
                    particleLife = 0.6,
                    maxParticles = 128,
                    spreadAngle = math.pi * 0.18,
                    speedMultiplier = 0.5,
                    trailColor = {0.3, 0.7, 1.0}
                }
            end

            if not (position and velocity and localEmitter and renderable) then goto continue_emitter end
            if not localEmitter.emitRate or not localEmitter.particleLife or not localEmitter.maxParticles or not localEmitter.spreadAngle or not localEmitter.speedMultiplier then goto continue_emitter end
            if not localEmitter.trailColor then localEmitter.trailColor = {0.3, 0.7, 1.0} end -- Fallback to blue if missing
            if not renderable.radius then goto continue_emitter end

            -- Check if thrust is active for this entity
            local isThrusting = false
            local trailColor = localEmitter.trailColor or {0.3, 0.7, 1.0}

            -- Player-controlled entity: check movement keys
            local controlledBy = ECS.getComponent(entityId, "ControlledBy")
            if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player") then
                local input = ECS.getComponent(controlledBy.pilotId, "InputControlled")
                if input then
                    local moveUp = HotkeyConfig.getHotkey("move_up")
                    local moveDown = HotkeyConfig.getHotkey("move_down")
                    local moveLeft = HotkeyConfig.getHotkey("move_left")
                    local moveRight = HotkeyConfig.getHotkey("move_right")
                    local CargoWindow = require('src.ui.cargo_window')
                    local searchFocused = CargoWindow and CargoWindow.isSearchFocused and CargoWindow:isSearchFocused()
                    if not searchFocused then
                        if love.keyboard.isDown(moveUp) or love.keyboard.isDown(moveDown) or
                           love.keyboard.isDown(moveLeft) or love.keyboard.isDown(moveRight) then
                            isThrusting = true
                        end
                    end
                end
                -- Use emitter's configured color (player default)
                trailColor = localEmitter.trailColor or trailColor
            else
                -- Non-player (enemy/AI) ships: detect active thrust from Force first, fallback to Acceleration
                local force = ECS.getComponent(entityId, "Force")
                if force then
                    local forceMag = math.sqrt((force.fx or 0)^2 + (force.fy or 0)^2)
                    if forceMag > 1e-3 then
                        isThrusting = true
                    end
                end

                if not isThrusting then
                    local acceleration = ECS.getComponent(entityId, "Acceleration")
                    if acceleration then
                        local accelMag = math.sqrt((acceleration.ax or 0)^2 + (acceleration.ay or 0)^2)
                        if accelMag > 10 then
                            isThrusting = true
                        end
                    end
                end

                -- Override color for enemies to red if not explicitly set
                if not emitter or (emitter and not emitter.trailColor) then
                    if isThrusting then
                        trailColor = {1.0, 0.2, 0.2}
                    end
                else
                    trailColor = localEmitter.trailColor or trailColor
                end
            end

            -- Only emit particles when thrust is active
            if isThrusting then
                -- Calculate ship speed for particle properties
                local speed = math.sqrt((velocity.vx or 0)^2 + (velocity.vy or 0)^2)
                local Constants = require('src.constants')
                local speedFactor = math.min(speed / Constants.player_max_speed, 1) -- 0 to 1

                -- Scale particle life and alpha with speed
                local minLife = localEmitter.particleLife * 0.5
                local maxLife = localEmitter.particleLife * 1.5
                local scaledLife = minLife + (maxLife - minLife) * speedFactor
                local minAlpha = 0.3
                local maxAlpha = 0.9
                local scaledAlpha = minAlpha + (maxAlpha - minAlpha) * speedFactor

                -- CONTINUOUS emission: emit every frame (no rate limiting)
                -- DOUBLE particle output: emit 2 particles per frame
                local particlesToEmit = 2

                for i = 1, particlesToEmit do
                    -- Check per-emitter capacity first (allow continuous streams per-ship)
                    local activeForThis = emitterActiveCounts[entityId] or 0
                    if activeForThis < localEmitter.maxParticles then
                        -- Calculate emission position (at ship center, no offset)
                        local emitX = position.x
                        local emitY = position.y

                        -- Calculate angle of movement
                        local angle = math.atan2(velocity.vy, velocity.vx)

                        -- Add some random spread
                        local spread = (math.random() - 0.5) * localEmitter.spreadAngle
                        local emitAngle = angle + spread

                        -- Calculate particle velocity (opposite to ship direction with some randomness)
                        local particleSpeed = math.max(speed, 50) * localEmitter.speedMultiplier  -- Minimum speed for visible trail
                        local particleVx = -math.cos(emitAngle) * particleSpeed + (math.random() - 0.5) * 20
                        local particleVy = -math.sin(emitAngle) * particleSpeed + (math.random() - 0.5) * 20

                        -- Acquire particle entity from pool
                        local particleId = EntityPool.acquire("trail_particle")

                        -- Update particle components with current data and tag owner
                        local particle = ECS.getComponent(particleId, "TrailParticle")
                        if particle then
                            particle.x = emitX
                            particle.y = emitY
                            particle.vx = particleVx
                            particle.vy = particleVy
                            particle.life = scaledLife
                            particle.maxLife = scaledLife
                            particle.size = Constants.trail_particle_size_min + math.random() * (Constants.trail_particle_size_max - Constants.trail_particle_size_min)
                            particle.color = {trailColor[1], trailColor[2], trailColor[3], scaledAlpha}
                            particle._owner = entityId
                        end
                        -- Increment particle counts (global + per-emitter)
                        particleCount = particleCount + 1
                        emitterActiveCounts[entityId] = (emitterActiveCounts[entityId] or 0) + 1
                    end
                end
            end
            ::continue_emitter::
        end
    end
}

return TrailSystem
