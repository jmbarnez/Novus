---@diagnostic disable: undefined-global
-- Magnet System - Handles magnetic collection of bits and items

local ECS = require('src.ecs')
local Notifications = require('src.ui.notifications')
local SoundSystem = require('src.systems.sound')


local MagnetSystem = {
    name = "MagnetSystem",
    priority = 5
}

function MagnetSystem.update(dt)
    -- Find only player ships with active magnetic fields and cargo
    local ships = ECS.getEntitiesWith({"MagneticField", "Cargo", "Position", "ControlledBy"})
    
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local cargo = ECS.getComponent(shipId, "Cargo")
        local shipPos = ECS.getComponent(shipId, "Position")
        
        if magField and magField.active and cargo and shipPos then
            -- Collect all Items in range (no ShatterBit needed)
            local items = ECS.getEntitiesWith({"Item", "Position"})
            local collectedByType = {}  -- Track collected items by type
            
            for _, itemId in ipairs(items) do
                local itemPos = ECS.getComponent(itemId, "Position")
                local item = ECS.getComponent(itemId, "Item")
                if itemPos and item then
                    local dx = shipPos.x - itemPos.x
                    local dy = shipPos.y - itemPos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    
                    if dist < magField.range then
                        -- Pull item toward ship
                        local pullSpeed = 500  -- Units per second
                        local pullStrength = pullSpeed * (1 - dist / magField.range)
                        local dirX = dx / (dist + 1e-6)
                        local dirY = dy / (dist + 1e-6)
                        itemPos.x = itemPos.x + dirX * pullStrength * dt
                        itemPos.y = itemPos.y + dirY * pullStrength * dt
                        
                        -- Collect if very close to ship
                        local collectDistance = 30
                        local newDist = math.sqrt((shipPos.x - itemPos.x)^2 + (shipPos.y - itemPos.y)^2)
                        if newDist < collectDistance then
                            local itemType = item.id or "stone"
                            local stack = ECS.getComponent(itemId, "Stack")
                            local quantity = (stack and stack.quantity) or 1
                            cargo.items[itemType] = (cargo.items[itemType] or 0) + quantity
                            collectedByType[itemType] = (collectedByType[itemType] or 0) + quantity
                            ECS.destroyEntity(itemId)
                        end
                    end
                end
            end
            
            -- Show notifications for each item type collected
            for itemType, count in pairs(collectedByType) do
                Notifications.addNotification(itemType, count)
            end
            
            -- Play quiet pickup sound if anything was collected
            if next(collectedByType) then
                if SoundSystem and SoundSystem.play then
                    SoundSystem.play("item_pickup", {volume = 0.3})
                end
            end
        end
    end
end

return MagnetSystem
