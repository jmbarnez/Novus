-- Render Effects Module - Handles visual effects (lasers, debris, hotspots, etc.)

local ECS = require('src.ecs')

local RenderEffects = {}

function RenderEffects.drawLasers()
    local laserEntities = ECS.getEntitiesWith({"LaserBeam"})
    for _, entityId in ipairs(laserEntities) do
        local laser = ECS.getComponent(entityId, "LaserBeam")
        if laser then
            local color = laser.color or {1, 1, 0, 1}

            -- Bright, vibrant glow effect
            love.graphics.setColor(color[1], color[2], color[3], 0.4)
            love.graphics.setLineWidth(3)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)

            -- Thin, bright core
            love.graphics.setColor(color[1], color[2], color[3], 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)

            love.graphics.setLineWidth(1)
        end
    end
end

function RenderEffects.drawDebris()
    local debrisEntities = ECS.getEntitiesWith({"DebrisParticle"})
    for _, entityId in ipairs(debrisEntities) do
        local particle = ECS.getComponent(entityId, "DebrisParticle")
        if particle then
            local alpha = particle.life / particle.maxLife
            if particle.color and particle.color[1] and particle.color[2] and particle.color[3] and particle.color[4] then
                love.graphics.setColor(
                    particle.color[1],
                    particle.color[2],
                    particle.color[3],
                    particle.color[4] * alpha
                )
                love.graphics.circle("fill", particle.x, particle.y, particle.size)
            end
        end
    end
end

function RenderEffects.drawTrails()
    local trailEntities = ECS.getEntitiesWith({"TrailParticle"})
    for _, entityId in ipairs(trailEntities) do
        local particle = ECS.getComponent(entityId, "TrailParticle")
        if particle and particle.life and particle.maxLife and particle.color and particle.x and particle.y and particle.size then
            local alpha = particle.life / particle.maxLife
            love.graphics.setColor(
                particle.color[1] or 1,
                particle.color[2] or 1,
                particle.color[3] or 1,
                (particle.color[4] or 1) * alpha
            )
            love.graphics.circle("fill", particle.x, particle.y, particle.size)
        end
    end
end

function RenderEffects.drawMagneticField()
    local ships = ECS.getEntitiesWith({"MagneticField", "Position", "ControlledBy"})
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local position = ECS.getComponent(shipId, "Position")
        if magField and magField.active and position then
            local radius = magField.range
            local time = love.timer.getTime()
            local pulse = 0.3 + 0.2 * math.sin(time * 4)
            love.graphics.setColor(0.4, 0.8, 1, pulse * 0.3)
            love.graphics.circle("line", position.x, position.y, radius)
            love.graphics.setColor(0.6, 0.9, 1, pulse * 0.2)
            love.graphics.circle("line", position.x, position.y, radius * 0.7)
        end
    end
end

function RenderEffects.drawHotspots()
    local hotspotEntities = ECS.getEntitiesWith({"Hotspot", "Position"})
    for _, hotspotId in ipairs(hotspotEntities) do
        local hotspot = ECS.getComponent(hotspotId, "Hotspot")
        local position = ECS.getComponent(hotspotId, "Position")
        
        if hotspot and position then
            local time = hotspot.timeSinceSpawn
            local pulse = 0.6 + 0.4 * math.sin(time * 3)
            
            local alphaMultiplier = 1.0
            if hotspot.timeRemaining < 3 then
                alphaMultiplier = hotspot.timeRemaining / 3
            end
            
            love.graphics.setColor(1, 0.5, 0.2, pulse * alphaMultiplier * 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", position.x, position.y, 12)
            
            love.graphics.setColor(1, 0.7, 0.3, pulse * alphaMultiplier * 0.6)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", position.x, position.y, 9)
            
            love.graphics.setColor(1, 1, 0.8, pulse * alphaMultiplier)
            love.graphics.circle("fill", position.x, position.y, 5)
            
            love.graphics.setColor(1, 0.4, 0.1, pulse * alphaMultiplier * 0.5)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", position.x, position.y, 14)
            
            love.graphics.setLineWidth(1)
        end
    end
end

function RenderEffects.drawTargetingIndicator()
    local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
    if #controllers > 0 then
        local inputComp = ECS.getComponent(controllers[1], "InputControlled")
        local targetId = inputComp and (inputComp.targetedEnemy or inputComp.targetingTarget)

        if inputComp and targetId then
            local targetPos = ECS.getComponent(targetId, "Position")
            local targetColl = ECS.getComponent(targetId, "Collidable")

            if targetPos and targetColl then
                local time = love.timer.getTime()
                local radius = targetColl.radius + 15

                if inputComp.targetedEnemy and inputComp.targetedEnemy == targetId then
                    local pulse = 0.5 + 0.3 * math.sin(time * 4)

                    love.graphics.setColor(1, 0.2, 0.2, pulse)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                    love.graphics.setColor(1, 0.5, 0.5, pulse * 0.7)
                    love.graphics.setLineWidth(1)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                elseif inputComp.targetingTarget and inputComp.targetingTarget == targetId then
                    local pulse = 0.4 + 0.4 * math.sin(time * 8)

                    love.graphics.setColor(1, 0.8, 0.2, pulse)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                    love.graphics.setColor(1, 0.9, 0.5, pulse * 0.7)
                    love.graphics.setLineWidth(1)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                end
            end
        end
    end
end

return RenderEffects

