---@diagnostic disable: undefined-global
-- Magnet System - Handles magnetic collection of bits and items

local ECS = require('src.ecs')
local Notifications = require('src.ui.notifications')
local SoundSystem = require('src.systems.sound')

local MagnetSystem = {
    name = "MagnetSystem",
    priority = 5.5  -- Run after projectiles but before destruction
}

function MagnetSystem.update(dt)
    -- Find all player ships with magnetic field, cargo, position, and controlled by player
    local ships = ECS.getEntitiesWith({"MagneticField", "Cargo", "Position", "ControlledBy"})
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local cargo = ECS.getComponent(shipId, "Cargo")
        local shipPos = ECS.getComponent(shipId, "Position")
        if magField and cargo and shipPos then
            -- Get remaining cargo capacity ONCE (to avoid repeated checks when full)
            local remainingVolume = cargo:getRemainingVolume()
            
            local collectedByType

            if remainingVolume > 0.001 then
                -- Get all items - ItemCleanupSystem keeps count manageable
                local items = ECS.getEntitiesWith({"Item", "Position"})
                collectedByType = {}
                
                -- Pre-calculate range squared for fast distance checks
                local outerRange = magField.range * 6
                local outerRangeSq = outerRange * outerRange
                
                for _, itemId in ipairs(items) do
                    local itemPos = ECS.getComponent(itemId, "Position")
                    local item = ECS.getComponent(itemId, "Item")
                    if itemPos and item then
                        -- Quick distance check using squared distance to avoid sqrt initially
                        local dx = shipPos.x - itemPos.x
                        local dy = shipPos.y - itemPos.y
                        local distSq = dx*dx + dy*dy
                        
                        -- Skip items beyond outer range immediately (avoids expensive sqrt)
                        if distSq <= outerRangeSq and remainingVolume > 0.001 then
                            local dist = math.sqrt(distSq)
                            
                            -- Extended attraction: strong pull inside magField.range, weaker pull out to an outer range
                            local dirX = dx / (dist + 1e-6)
                            local dirY = dy / (dist + 1e-6)
                            if dist < magField.range then
                                -- Stronger pull when inside the main magnetic range
                                local pullSpeed = 500
                                local pullStrength = pullSpeed * (1 - dist / magField.range)
                                itemPos.x = itemPos.x + dirX * pullStrength * dt
                                itemPos.y = itemPos.y + dirY * pullStrength * dt
                            else
                                -- Weak long-range attraction to start moving items toward the ship
                                local farPullSpeed = 150
                                local outerRange = magField.range * 6
                                -- Fade linearly from farPullSpeed at outerRange to near 0 at magField.range
                                local near = magField.range
                                local t = (outerRange - dist) / (outerRange - near)
                                t = math.max(0, math.min(1, t))
                                local pullStrength = farPullSpeed * t
                                itemPos.x = itemPos.x + dirX * pullStrength * dt
                                itemPos.y = itemPos.y + dirY * pullStrength * dt
                            end
                            -- Collect if very close to ship
                            local collectDistance = 5
                            local collectDistanceSq = collectDistance * collectDistance
                            if distSq < collectDistanceSq then
                                local itemType = item.id or "stone"
                                local stack = ECS.getComponent(itemId, "Stack")
                                local quantity = (stack and stack.quantity) or 1

                                -- Check if this specific item can be added
                                if cargo:canAddItem(itemType, quantity) then
                                    local added = cargo:addItem(itemType, quantity)
                                    if added then
                                        collectedByType[itemType] = (collectedByType[itemType] or 0) + quantity
                                        ECS.destroyEntity(itemId)
                                        -- Update remaining volume
                                        remainingVolume = cargo:getRemainingVolume()
                                        if remainingVolume <= 0.001 then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if collectedByType then
                for itemType, count in pairs(collectedByType) do
                    Notifications.addItemNotification(itemType, count)
                end
                if next(collectedByType) then
                    if SoundSystem and SoundSystem.play then
                        -- Increase pickup sound base loudness: use full fractional volume (1.0)
                        -- SoundSystem.play expects a fractional volume in 0.0-1.0 to scale the base SFX volume.
                        SoundSystem.play("item_pickup", {volume = 1.0})
                    end
                end
            end
        end
    end
end

return MagnetSystem
