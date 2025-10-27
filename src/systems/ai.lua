---@diagnostic disable: undefined-global
-- AI System - Unified behavior-based architecture
-- Single system handles all AI types (combat, mining) with pluggable behavior handlers

local ECS = require('src.ecs')
local Behaviors = require('src.systems.ai_behaviors')
local EntityHelpers = require('src.entity_helpers')

local AISystem = {
    name = "AISystem",
    priority = 9,
}

-- ============================================================================
-- BEHAVIOR REGISTRY - Easy to add new behaviors
-- ============================================================================

local BehaviorHandlers = {
    patrol = Behaviors.Patrol.update,
    chase = Behaviors.Chase.update,
    orbit = Behaviors.Orbit.update,
    aggressive = Behaviors.Aggressive.update,
}

-- ============================================================================
-- UTILITIES
-- ============================================================================

local function distSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

-- Trigger aggressive state when AI entity takes damage
function AISystem.triggerAggressiveReaction(victimId, attackerId)
    local ai = ECS.getComponent(victimId, "AI")
    if not ai then return end
    
    -- Set aggressive state for any AI when attacked
    ai.aggressiveTimer = ai.aggressiveDuration or 5.0
    ai.lastAttacker = attackerId
    ai.state = "aggressive"
    
    -- For mining AI, switch to combat mode when attacked
    if ai.type == "mining" then
        ai._wasMining = true  -- Track original mining state for potential return
    end
end

-- ============================================================================
-- STATE TRANSITIONS - Determine which behavior to use
-- ============================================================================

local function updateAIState(ai, pos, playerPos, turret, design, dt)
    -- If mining AI has been attacked, allow it to enter combat states
    local isMiningBeingAttacked = ai.type == "mining" and ai.aggressiveTimer and ai.aggressiveTimer > 0
    
    -- NEVER allow mining AI to enter combat states UNLESS they're being attacked
    if ai.type == "mining" and not isMiningBeingAttacked then
        return
    end

    -- Update aggressive timer
    if ai.aggressiveTimer and ai.aggressiveTimer > 0 then
        ai.aggressiveTimer = ai.aggressiveTimer - dt
        if ai.aggressiveTimer <= 0 then
            ai.aggressiveTimer = 0
            ai.lastAttacker = nil
            
            -- Return mining AI to mining state when aggressive timer expires
            if ai.type == "mining" and ai._wasMining then
                ai.state = "mining"
                return
            end
        end
    end

    -- If in aggressive state, stay aggressive regardless of detection range
    if ai.aggressiveTimer and ai.aggressiveTimer > 0 then
        ai.state = "aggressive"
        return
    end

    if not playerPos then
        ai.state = "patrol"
        return
    end

    local dsq = distSq(pos.x, pos.y, playerPos.x, playerPos.y)
    local dist = math.sqrt(dsq)
    local detectionRadiusSq = ai.detectionRadius * ai.detectionRadius

    if dsq < detectionRadiusSq then
        -- Player detected
        if design and design.name == "Red Scout" and turret and turret.moduleName then
            ai.state = "orbit"
        else
            ai.state = "chase"
        end
        -- Clear idle turret swing when engaged
        ai._swingTimer = nil
        ai._swingAngle = nil
    else
        -- Player out of range - return to patrol
        if ai.state == "chase" or ai.state == "orbit" then
            ai.state = "patrol"
        end
    end
end

-- ==== Enemy Respawn Logic BEGIN ====
local respawnTimer = 0
local respawnInterval = 60  -- seconds between enemy respawns (slow)

function AISystem._getEnemyCap()
    -- Determine cap from current world config (if available)
    local WorldLoader = require('src.world_loader')
    local world = WorldLoader.getCurrentWorld and WorldLoader.getCurrentWorld()
    if world and world.enemies and world.enemies.types then
        local cap = 0
        for _, count in pairs(world.enemies.types) do
            cap = cap + count
        end
        return cap or 10
    end
    return 10 -- fallback
end

function AISystem._countEnemies()
    local ECS = require('src.ecs')
    local aiEntities = ECS.getEntitiesWith({"AI", "Position"})
    local active = 0
    for _, eid in ipairs(aiEntities) do
        -- Only count enemies not controlled by player
        if not ECS.hasComponent(eid, "ControlledBy") then
            active = active + 1
        end
    end
    return active
end

function AISystem._respawnEnemy()
    local WorldLoader = require('src.world_loader')
    local world = WorldLoader.getCurrentWorld and WorldLoader.getCurrentWorld()
    if not world or not world.enemies then return end
    -- Choose enemy type to spawn (weighted random if multiple)
    local candidates = {}
    for k, v in pairs(world.enemies.types or {}) do
        for i=1, v do
            table.insert(candidates, k)
        end
    end
    if #candidates == 0 then return end
    local enemyType = candidates[math.random(#candidates)]

    -- Pick spawn location (use logic from initial spawn, e.g., random in world bounds)
    local config = world.enemies
    WorldLoader.spawnEnemy(enemyType, config)
end

-- ============================================================================
-- MAIN UPDATE LOOP
-- ============================================================================

function AISystem.update(dt)
    -- Enemy respawn logic
    respawnTimer = respawnTimer + dt
    if respawnTimer >= respawnInterval then
        respawnTimer = 0
        local count = AISystem._countEnemies()
        local cap = AISystem._getEnemyCap()
        if count < cap then
            AISystem._respawnEnemy()
        end
    end
    
    -- Get player position using helper function
    local playerX, playerY = EntityHelpers.getPlayerPosition()
    local playerPos = nil
    if playerX ~= 0 or playerY ~= 0 then
        playerPos = {x = playerX, y = playerY}
    end

    -- Update all AI entities
    local aiEntities = ECS.getEntitiesWith({"AI", "Position", "Velocity"})
    for _, entityId in ipairs(aiEntities) do
        local ai = ECS.getComponent(entityId, "AI")
        local pos = ECS.getComponent(entityId, "Position")
        local vel = ECS.getComponent(entityId, "Velocity")
        local turret = ECS.getComponent(entityId, "Turret")
        
        if not (ai and pos and vel) then goto continue end

        -- Skip mining AI if handled by separate system UNLESS it's in aggressive state
        if ai.type == "mining" then
            -- If mining AI is being attacked, let it continue to combat logic
            if not (ai.aggressiveTimer and ai.aggressiveTimer > 0) then
                -- Ensure mining AI stays in mining state when not aggressive
                ai.state = "mining"
                goto continue
            end
        end
        
        -- Get ship design
        local wreckage = ECS.getComponent(entityId, "Wreckage")
        local ShipLoader = require('src.ship_loader')
        local design = wreckage and ShipLoader.getDesign(wreckage.sourceShip)
        local thrustForce = design and design.thrustForce or 0
        
        if thrustForce == 0 then
            goto continue
        end

        -- Initialize spawn position
        ai.spawnX = ai.spawnX or pos.x
        ai.spawnY = ai.spawnY or pos.y
        
        -- Skip if no turret module
        if not turret or not turret.moduleName then
            goto continue
        end

        -- Update state based on player detection
        updateAIState(ai, pos, playerPos, turret, design, dt)
        
        -- Execute behavior for current state
        local behaviorHandler = BehaviorHandlers[ai.state]
        if behaviorHandler then
        if ai.state == "patrol" then
                behaviorHandler(entityId, ai, pos, vel, turret, design, dt)
                -- Swing turret when idle
                if not playerPos then
                    Behaviors.Patrol.swingTurret(turret, pos, dt)
                end
            else
                behaviorHandler(entityId, ai, pos, vel, turret, design, playerPos, dt)
            end
        end

        ::continue::
    end
end

return AISystem
