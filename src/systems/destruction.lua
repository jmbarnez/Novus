-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local ItemDefs = require('src.items.item_loader')

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

            -- Spawn items if this is an asteroid
            local asteroid = ECS.getComponent(entityId, "Asteroid")
            if asteroid then
                DestructionSystem.spawnItemDrops(pos.x, pos.y)
            end

            ECS.destroyEntity(entityId)
        end
    end
end

-- Spawn item drops around the asteroid destruction point
function DestructionSystem.spawnItemDrops(x, y)
    local itemTypes = {"stone", "iron"}
    local dropCount = math.random(2, 4) -- Spawn 2-4 items
    print("Spawning " .. dropCount .. " items at (" .. x .. ", " .. y .. ")")
    
    for i = 1, dropCount do
        -- Randomly choose an item type
        local itemType = itemTypes[math.random(#itemTypes)]
        local itemDef = ItemDefs[itemType]
        if not itemDef then return end
        
        -- Spawn item in random direction around asteroid
        local angle = math.random() * math.pi * 2  -- Random angle 0-2π
        local distance = math.random(20, 50)  -- Distance from asteroid center
        
        local itemX = x + math.cos(angle) * distance
        local itemY = y + math.sin(angle) * distance
        
        -- Random velocity away from asteroid
        local speed = math.random(30, 80)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        -- Create item entity
        local itemId = ECS.createEntity()
        ECS.addComponent(itemId, "Position", Components.Position(itemX, itemY))
        ECS.addComponent(itemId, "Velocity", Components.Velocity(vx, vy))
        ECS.addComponent(itemId, "Item", {id = itemType, def = itemDef})
        ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
        
        print("Spawned " .. itemType .. " item at (" .. itemX .. ", " .. itemY .. ")")
    end
end

return DestructionSystem