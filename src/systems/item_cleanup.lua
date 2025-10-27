---@diagnostic disable: undefined-global
-- Item Cleanup System - Removes items that are far from the player
-- Prevents performance degradation from thousands of accumulated items

local ECS = require('src.ecs')
local EntityHelpers = require('src.entity_helpers')

local ItemCleanupSystem = {
    name = "ItemCleanupSystem",
    priority = 2.5  -- Run early, before physics
}

-- Maximum distance from player before items are removed
local CLEANUP_DISTANCE = 3000
-- Time (in seconds) items must be far from player before cleanup
local CLEANUP_DELAY = 30

function ItemCleanupSystem.update(dt)
    -- Get player position
    local playerId = EntityHelpers.getPlayerShip()
    if not playerId then return end
    
    local playerPos = ECS.getComponent(playerId, "Position")
    if not playerPos then return end
    
    -- Get all items in the world
    local items = ECS.getEntitiesWith({"Item", "Position"})
    
    for _, itemId in ipairs(items) do
        local itemPos = ECS.getComponent(itemId, "Position")
        if itemPos then
            -- Calculate distance from player
            local dx = playerPos.x - itemPos.x
            local dy = playerPos.y - itemPos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- Check if item is far from player
            if dist > CLEANUP_DISTANCE then
                -- Get or create a cleanup timestamp component
                local cleanup = ECS.getComponent(itemId, "ItemCleanup")
                if not cleanup then
                    -- First time we notice this item is far away
                    local Components = require('src.components')
                    ECS.addComponent(itemId, "ItemCleanup", Components.ItemCleanup(love.timer.getTime()))
                else
                    -- Check if enough time has passed
                    local timeFarAway = love.timer.getTime() - cleanup.farAwayTimestamp
                    if timeFarAway > CLEANUP_DELAY then
                        -- Item has been far away long enough, remove it
                        ECS.destroyEntity(itemId)
                    end
                end
            else
                -- Item is within range, remove any cleanup marker
                if ECS.hasComponent(itemId, "ItemCleanup") then
                    ECS.removeComponent(itemId, "ItemCleanup")
                end
            end
        end
    end
end

return ItemCleanupSystem

