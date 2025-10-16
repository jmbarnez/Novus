---@diagnostic disable: undefined-global
-- Pickup System - Handles item collection on player contact

local ECS = require('src.ecs')
local Notifications = require('src.ui.notifications')

local PickupSystem = {
    name = "MagnetSystem"  -- Keep name for compatibility
}

function PickupSystem.update(dt)
    -- Get all entities with Cargo (the player)
    local cargoEntities = ECS.getEntitiesWith({"Cargo", "Position", "Collidable"})
    
    for _, cargoId in ipairs(cargoEntities) do
        local cargo = ECS.getComponent(cargoId, "Cargo")
        local cargoPos = ECS.getComponent(cargoId, "Position")
        local coll = ECS.getComponent(cargoId, "Collidable")
        
        if cargo and cargoPos and coll then
            -- Get all items in the world
            local itemEntities = ECS.getEntitiesWith({"Item", "Position", "Collidable"})
            
            for _, itemId in ipairs(itemEntities) do
                local itemComp = ECS.getComponent(itemId, "Item")
                local itemPos = ECS.getComponent(itemId, "Position")
                local itemColl = ECS.getComponent(itemId, "Collidable")
                local stack = ECS.getComponent(itemId, "Stack")
                
                if itemComp and itemPos and itemColl then
                    local dx = cargoPos.x - itemPos.x
                    local dy = cargoPos.y - itemPos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    local minDist = coll.radius + itemColl.radius
                    
                    -- If player touches item, collect it
                    if dist < minDist then
                        local quantity = stack and stack.quantity or 1
                        cargo.items[itemComp.id] = (cargo.items[itemComp.id] or 0) + quantity
                        
                        -- Show notification for item collected
                        Notifications.addNotification(itemComp.id, quantity, cargoPos.x, cargoPos.y)
                        
                        ECS.destroyEntity(itemId)
                        
                        -- Call item's onCollect hook if it exists
                        if itemComp.def and itemComp.def.onCollect then
                            itemComp.def:onCollect(cargoId)
                        end
                    end
                end
            end
        end
    end
end

return PickupSystem
