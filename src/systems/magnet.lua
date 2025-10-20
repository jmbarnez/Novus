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
    -- Find all player ships with magnetic field, cargo, position, and controlled by player
    local ships = ECS.getEntitiesWith({"MagneticField", "Cargo", "Position", "ControlledBy"})
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local cargo = ECS.getComponent(shipId, "Cargo")
        local shipPos = ECS.getComponent(shipId, "Position")
        if magField and cargo and shipPos then
            -- Always attract and collect items, ignore magneticField.active
            local items = ECS.getEntitiesWith({"Item", "Position"})
            local collectedByType = {}
            for _, itemId in ipairs(items) do
                local itemPos = ECS.getComponent(itemId, "Position")
                local item = ECS.getComponent(itemId, "Item")
                if itemPos and item then
                    local dx = shipPos.x - itemPos.x
                    local dy = shipPos.y - itemPos.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    -- Extended attraction: strong pull inside magField.range, weaker pull out to an outer range
                    local outerRange = magField.range * 6
                    if dist < outerRange then
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
            for itemType, count in pairs(collectedByType) do
                Notifications.addNotification(itemType, count)
            end
            if next(collectedByType) then
                if SoundSystem and SoundSystem.play then
                    SoundSystem.play("item_pickup", {volume = 0.3})
                end
            end
        end
    end
end

return MagnetSystem
