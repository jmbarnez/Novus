-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem

local DestructionSystem = {
    name = "DestructionSystem",
}

function DestructionSystem.update(dt)
    local entities = ECS.getEntitiesWith({"Durability"})

    for _, entityId in ipairs(entities) do
        local durability = ECS.getComponent(entityId, "Durability")
        if durability.current <= 0 then
            local pos = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable") -- Get renderable component for color
            local color = renderable and renderable.color or {0.5, 0.5, 0.5, 1} -- Default grey if no color
            
            -- Call DebrisSystem to create debris particles
            DebrisSystem.createDebris(pos.x, pos.y, nil, color)

            ECS.destroyEntity(entityId)
        end
    end
end

return DestructionSystem