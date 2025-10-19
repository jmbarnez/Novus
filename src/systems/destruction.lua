-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local ItemDefs = require('src.items.item_loader')

local DestructionSystem = {
    name = "DestructionSystem",
    priority = 6
}

function DestructionSystem.update(dt)
    -- Entities to check: any with Durability or Hull
    local entities = ECS.getEntitiesWith({"Durability"})
    local hullEntities = ECS.getEntitiesWith({"Hull"})
    for _, hid in ipairs(hullEntities) do table.insert(entities, hid) end

    for _, entityId in ipairs(entities) do
        local durability = ECS.getComponent(entityId, "Durability")
        local hull = ECS.getComponent(entityId, "Hull")
        local destroyed = false
        if durability and durability.current <= 0 then
            destroyed = true
        elseif hull and hull.current <= 0 then
            destroyed = true
        end
        if destroyed then
            local pos = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable") -- Get renderable component for color
            local color = renderable and renderable.color or {0.5, 0.5, 0.5, 1} -- Default grey if no color
            
            -- Log if this is a projectile being destroyed
            local proj = ECS.getComponent(entityId, "Projectile")
            if proj then
                print(string.format("[Destruction] Destroying projectile %d", entityId))
            end
            
            -- Call DebrisSystem to create debris particles
            if pos then
                DebrisSystem.createDebris(pos.x, pos.y, nil, color)
            end

            -- Spawn items if this is an asteroid
            local asteroid = ECS.getComponent(entityId, "Asteroid")
            if asteroid and pos then
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
    -- ...existing code...
    
    -- Group items by type for stacking
    local itemsByType = {}
    for i = 1, dropCount do
        local itemType = itemTypes[math.random(#itemTypes)]
        itemsByType[itemType] = (itemsByType[itemType] or 0) + 1
    end
    
    -- Spawn one entity per item type with stack quantity
    for itemType, quantity in pairs(itemsByType) do
        local itemDef = ItemDefs[itemType]
        if itemDef then
            -- Spawn item in random direction around asteroid
            local angle = math.random() * math.pi * 2  -- Random angle 0-2π
            local distance = math.random(70, 120)  -- Distance from asteroid center (further to avoid overlap)
            
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
            ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.5))  -- Friction, mass
            ECS.addComponent(itemId, "Item", {id = itemType, def = itemDef})
            ECS.addComponent(itemId, "Stack", Components.Stack(quantity))  -- Add stack with quantity
            ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
            -- (REMOVED) No collider for dropped items!
        end
    end
end

return DestructionSystem