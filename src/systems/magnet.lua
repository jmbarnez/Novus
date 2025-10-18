---@diagnostic disable: undefined-global
-- Pickup System - Handles item collection on player contact

local ECS = require('src.ecs')
local Notifications = require('src.ui.notifications')
local SoundSystem = require('src.systems.sound')


local PickupSystem = {
    name = "MagnetSystem",  -- Keep name for compatibility
    priority = 5
}

function PickupSystem.update(dt)
    -- Find the pilot and their controlled drone
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local pilotCargo = ECS.getComponent(pilotId, "Cargo")
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local dronePos = ECS.getComponent(droneId, "Position")
    local coll = ECS.getComponent(droneId, "Collidable")
    local magnet = ECS.getComponent(droneId, "Magnet")
    if not pilotCargo or not dronePos or not coll or not magnet then return end
        
        if pilotCargo and dronePos and coll and magnet then
            -- Get all items in the world
            local itemEntities = ECS.getEntitiesWith({"Item", "Position"})
            
            for _, itemId in ipairs(itemEntities) do
                local itemComp = ECS.getComponent(itemId, "Item")
                local itemPos = ECS.getComponent(itemId, "Position")
                local stack = ECS.getComponent(itemId, "Stack")
                if itemComp and itemPos then
                    local dx = dronePos.x - itemPos.x
                    local dy = dronePos.y - itemPos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    -- Magnet effect: pull item toward drone
                    if magnet and dist < magnet.range then
                        local pullStrength = magnet.pullSpeed * (1 - dist / magnet.range)
                        local dirX = dx / (dist + 1e-6)
                        local dirY = dy / (dist + 1e-6)
                        itemPos.x = itemPos.x + dirX * pullStrength * dt
                        itemPos.y = itemPos.y + dirY * pullStrength * dt
                    end
                    -- Pickup if close enough
                    if magnet and dist < magnet.collectDistance then
                        local quantity = stack and stack.quantity or 1
                        pilotCargo.items[itemComp.id] = (pilotCargo.items[itemComp.id] or 0) + quantity
                        Notifications.addNotification(itemComp.id, quantity, dronePos.x, dronePos.y)
                        print("[Pickup] Collected item: " .. tostring(itemComp.id) .. " x" .. tostring(quantity))
                        -- Play pickup sound (loaded asset)
                        if SoundSystem and SoundSystem.play then
                            SoundSystem.play("item_pickup", {volume = 0.9})
                        end
                        ECS.destroyEntity(itemId)
                        if itemComp.def and itemComp.def.onCollect then
                            itemComp.def:onCollect(pilotId)
                        end
                end
            end
        end
    end
end

return PickupSystem
