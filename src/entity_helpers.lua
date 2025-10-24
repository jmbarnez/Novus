---@diagnostic disable: undefined-global
-- Entity Helpers - Common entity creation and manipulation utilities
-- Decouples systems by providing standalone functions for common operations
-- Previously these were tightly coupled through ECS.getSystem() calls

local ECS = require('src.ecs')
local Components = require('src.components')

local EntityHelpers = {}

-- Create a shield impact visual effect at a position
-- @param x number: X position of impact
-- @param y number: Y position of impact
-- @param shipId number: Entity ID of ship that was hit
-- @return number: Entity ID of the created impact effect
function EntityHelpers.createShieldImpact(x, y, shipId)
    local impactId = ECS.createEntity()
    ECS.addComponent(impactId, "ShieldImpact", Components.ShieldImpact(x, y, shipId))
    return impactId
end

-- Notify AI system that an entity took damage
-- Does this by setting a component flag that the AI system will detect
-- @param entityId number: Entity that took damage
-- @param attackerId number: Entity that dealt the damage (optional)
function EntityHelpers.notifyAIDamage(entityId, attackerId)
    -- AI system detects damage through component queries
    -- We can add a temporary "Damaged" component or flag
    local ai = ECS.getComponent(entityId, "AI")
    if ai then
        ai.lastDamagedBy = attackerId
        ai.lastDamagedTime = love.timer.getTime()
    end
end

return EntityHelpers
