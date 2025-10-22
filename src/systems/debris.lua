---@diagnostic disable: undefined-global
-- Debris System - Manages explosion debris particles

local ECS = require('src.ecs')

local DebrisSystem = {
    name = "DebrisSystem",
    priority = 9
}

function DebrisSystem.update(dt)
    local entities = ECS.getEntitiesWith({"DebrisParticle"})

    for _, entityId in ipairs(entities) do
        local particle = ECS.getComponent(entityId, "DebrisParticle")

        -- Update particle position
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt

        -- Update lifetime
        particle.life = particle.life - dt

        -- Remove dead particles
        if particle.life <= 0 then
            ECS.destroyEntity(entityId)
        end
    end
end

function DebrisSystem.draw()
    local entities = ECS.getEntitiesWith({"DebrisParticle"})

    for _, entityId in ipairs(entities) do
        local particle = ECS.getComponent(entityId, "DebrisParticle")
        if particle then
            -- Use a grey color for debris
            local r, g, b = 0.8, 0.8, 0.8 -- Default light grey
            if particle.color and particle.color[1] and particle.color[2] and particle.color[3] then
                r, g, b = particle.color[1], particle.color[2], particle.color[3]
            end
            love.graphics.setColor(r, g, b, particle.life / particle.maxLife) -- Fade out
            love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
        end
    end

    -- Reset color to white for other rendering
    love.graphics.setColor(1, 1, 1, 1)
end


function DebrisSystem.createDebris(x, y, numParticles, color)
    numParticles = numParticles or 3 -- Reduced default from 5 to 3
    color = color or {0.8, 0.8, 0.8, 1} -- Default light grey
    for _ = 1, numParticles do
        local angle = math.random() * 2 * math.pi
        local speed = math.random(20, 80)
        local life = math.random(0.2, 0.6)
        local size = math.random(0.5, 1.5)

        local entityId = ECS.createEntity()
        ECS.addComponent(entityId, "DebrisParticle", {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life, -- Ensure maxLife is set to initial life
            size = size,
            color = color
        })
    end
end

return DebrisSystem
