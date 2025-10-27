---@diagnostic disable: undefined-global
-- Entity Helpers - Centralized functions for consistent entity queries
-- Provides standardized ways to find player, enemy, and other entity types

local ECS = require('src.ecs')

local EntityHelpers = {}
local CachedAISystem = nil
local CachedShieldImpactSystem = nil

-- Get the player's pilot entity (the entity with Player and InputControlled components)
-- Returns the pilot entity ID, or nil if not found
function EntityHelpers.getPlayerPilot()
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities > 0 then
        return pilotEntities[1]
    end
    return nil
end

-- Get the player's controlled ship entity
-- Returns the ship entity ID, or nil if not found
function EntityHelpers.getPlayerShip()
    local pilotId = EntityHelpers.getPlayerPilot()
    if not pilotId then 
        return nil 
    end
    
    local input = ECS.getComponent(pilotId, "InputControlled")
    if input and input.targetEntity then
        return input.targetEntity
    end
    return nil
end

-- Get the player's position (from their controlled ship)
-- Returns x, y coordinates, or 0, 0 if not found
function EntityHelpers.getPlayerPosition()
    local shipId = EntityHelpers.getPlayerShip()
    if not shipId then 
        return 0, 0 
    end
    
    local pos = ECS.getComponent(shipId, "Position")
    if pos then
        return pos.x, pos.y
    end
    return 0, 0
end

-- Get the player's velocity (from their controlled ship)
-- Returns vx, vy, or 0, 0 if not found
function EntityHelpers.getPlayerVelocity()
    local shipId = EntityHelpers.getPlayerShip()
    if not shipId then return 0, 0 end
    
    local vel = ECS.getComponent(shipId, "Velocity")
    if vel then
        return vel.vx, vel.vy
    end
    return 0, 0
end

-- Get all enemy entities (ships with AI component, not player-controlled)
-- Returns array of entity IDs
function EntityHelpers.getEnemyShips()
    local enemies = {}
    local aiEntities = ECS.getEntitiesWith({"AI", "Position"})
    
    for _, id in ipairs(aiEntities) do
        local controlledBy = ECS.getComponent(id, "ControlledBy")
        local isPlayerControlled = controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player")
        
        -- Only include if not player-controlled
        if not isPlayerControlled then
            table.insert(enemies, id)
        end
    end
    
    return enemies
end

-- Get all enemy entities with specific AI type
-- @param aiType string: "combat", "mining", etc.
-- Returns array of entity IDs
function EntityHelpers.getEnemyShipsByType(aiType)
    local enemies = {}
    local aiEntities = ECS.getEntitiesWith({"AI", "Position"})
    
    for _, id in ipairs(aiEntities) do
        local ai = ECS.getComponent(id, "AI")
        local controlledBy = ECS.getComponent(id, "ControlledBy")
        
        -- Only include if not player-controlled and matches AI type
        if ai and ai.type == aiType and 
           not (controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player")) then
            table.insert(enemies, id)
        end
    end
    
    return enemies
end

-- Get all ships (both player and enemy)
-- Returns array of entity IDs
function EntityHelpers.getAllShips()
    return ECS.getEntitiesWith({"Hull", "Position"})
end

-- Check if an entity is player-controlled
-- @param entityId number: Entity ID to check
-- Returns boolean
function EntityHelpers.isPlayerControlled(entityId)
    local controlledBy = ECS.getComponent(entityId, "ControlledBy")
    if not controlledBy or not controlledBy.pilotId then
        return false
    end
    
    return ECS.hasComponent(controlledBy.pilotId, "Player")
end

-- Get all player-controlled ships (including the player's ship)
-- Returns array of entity IDs
function EntityHelpers.getPlayerControlledShips()
    local playerShips = {}
    local controlledShips = ECS.getEntitiesWith({"ControlledBy"})
    
    for _, shipId in ipairs(controlledShips) do
        if EntityHelpers.isPlayerControlled(shipId) then
            table.insert(playerShips, shipId)
        end
    end
    
    return playerShips
end

-- Get all non-player ships (enemies and neutral ships)
-- Returns array of entity IDs
function EntityHelpers.getNonPlayerShips()
    local nonPlayerShips = {}
    local allShips = EntityHelpers.getAllShips()

    for _, shipId in ipairs(allShips) do
        if not EntityHelpers.isPlayerControlled(shipId) then
            table.insert(nonPlayerShips, shipId)
        end
    end

    return nonPlayerShips
end

-- Notify the AI system that an entity has taken damage so it can react aggressively
-- @param victimId number: Entity that took damage
-- @param sourceId number|nil: Entity responsible for the damage (projectile, ship, etc.)
function EntityHelpers.notifyAIDamage(victimId, sourceId)
    if not victimId then return end
    -- Determine attacker entity (resolve from projectile owner if necessary)
    local attackerId = sourceId
    if sourceId then
        local projectile = ECS.getComponent(sourceId, "Projectile")
        if projectile and projectile.ownerId and projectile.ownerId ~= 0 then
            attackerId = projectile.ownerId
        else
            local controlledBy = ECS.getComponent(sourceId, "ControlledBy")
            if controlledBy and controlledBy.pilotId then
                attackerId = controlledBy.pilotId
            end
        end
    end

    -- Directly update the AI component on the victim to trigger aggressive reaction.
    local ai = ECS.getComponent(victimId, "AI")
    if not ai then return end

    ai.aggressiveTimer = ai.aggressiveDuration or 5.0
    ai.lastAttacker = attackerId
    ai.state = "aggressive"
    -- If this was a mining AI, remember its previous mining state so it can return later
    if ai.type == "mining" then
        ai._wasMining = true
    end
end

-- Create a shield impact visual effect
-- @param x number: World X position of the impact
-- @param y number: World Y position of the impact
-- @param shipId number: Entity ID of the ship whose shield was hit
-- @return number|nil: Entity ID of the created impact effect, or nil on failure
function EntityHelpers.createShieldImpact(x, y, shipId)
    if not CachedShieldImpactSystem then
        local ok, module = pcall(require, 'src.systems.shield_impact')
        if ok then
            CachedShieldImpactSystem = module
        else
            return nil
        end
    end

    if not CachedShieldImpactSystem or not CachedShieldImpactSystem.createImpact then
        return nil
    end

    return CachedShieldImpactSystem.createImpact(x, y, shipId)
end

return EntityHelpers
