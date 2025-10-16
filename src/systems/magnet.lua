---@diagnostic disable: undefined-global
-- Magnet System - Handles item attraction and collection for entities with Magnet components

local ECS = require('src.ecs')

local MagnetSystem = {
    name = "MagnetSystem"
}

function MagnetSystem.update(dt)
    -- Get all entities with Magnet, Position, and Cargo components
    local magnetEntities = ECS.getEntitiesWith({"Magnet", "Position", "Cargo"})
    
    for _, magnetId in ipairs(magnetEntities) do
        local magnet = ECS.getComponent(magnetId, "Magnet")
        local magnetPos = ECS.getComponent(magnetId, "Position")
        local cargo = ECS.getComponent(magnetId, "Cargo")
        
        if magnet and magnetPos and cargo then
            -- Get all items in the world
            local itemEntities = ECS.getEntitiesWith({"Item", "Position", "Velocity"})
            
            for _, itemId in ipairs(itemEntities) do
                local itemComp = ECS.getComponent(itemId, "Item")
                local pos = ECS.getComponent(itemId, "Position")
                local vel = ECS.getComponent(itemId, "Velocity")
                
                if itemComp and pos and vel then
                    local dx = magnetPos.x - pos.x
                    local dy = magnetPos.y - pos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    
                    -- If item is within magnet range, pull it
                    if dist < magnet.range and dist > 0 then
                        vel.vx = dx/dist * magnet.pullSpeed
                        vel.vy = dy/dist * magnet.pullSpeed
                        
                        -- If close enough, collect the item
                        if dist < magnet.collectDistance then
                            cargo.items[itemComp.id] = (cargo.items[itemComp.id] or 0) + 1
                            ECS.destroyEntity(itemId)
                            
                            -- Call item's onCollect hook if it exists
                            if itemComp.def and itemComp.def.onCollect then
                                itemComp.def:onCollect(magnetId)
                            end
                        end
                    end
                end
            end
        end
    end
end

return MagnetSystem
