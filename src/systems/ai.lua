---@diagnostic disable: undefined-global
-- AI System - Unified behavior-based architecture
-- Single system handles all AI types (combat, mining) with pluggable behavior handlers

local ECS = require('src.ecs')
local Behaviors = require('src.systems.ai_behaviors')

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
}

-- ============================================================================
-- UTILITIES
-- ============================================================================

local function distSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

-- ============================================================================
-- STATE TRANSITIONS - Determine which behavior to use
-- ============================================================================

local function updateAIState(ai, pos, playerPos, turret, design)
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

-- ============================================================================
-- MAIN UPDATE LOOP
-- ============================================================================

function AISystem.update(dt)
    -- Get player position
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local playerPos = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerPos = ECS.getComponent(input.targetEntity, "Position")
        end
    end

    -- Update all AI entities
    local aiEntities = ECS.getEntitiesWith({"AI", "Position", "Velocity"})
    for _, eid in ipairs(aiEntities) do
        local ai = ECS.getComponent(eid, "AI")
        local pos = ECS.getComponent(eid, "Position")
        local vel = ECS.getComponent(eid, "Velocity")
        local turret = ECS.getComponent(eid, "Turret")
        
        if not (ai and pos and vel) then goto continue end

        -- Skip mining AI if handled by separate system
        if ai.type == "mining" then
            goto continue
        end
        
        -- Get ship design
        local wreckage = ECS.getComponent(eid, "Wreckage")
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
        updateAIState(ai, pos, playerPos, turret, design)
        
        -- Execute behavior for current state
        local behaviorHandler = BehaviorHandlers[ai.state]
        if behaviorHandler then
        if ai.state == "patrol" then
                behaviorHandler(eid, ai, pos, vel, turret, design, dt)
                -- Swing turret when idle
                if not playerPos then
                    Behaviors.Patrol.swingTurret(turret, pos, dt)
                end
            else
                behaviorHandler(eid, ai, pos, vel, turret, design, playerPos, dt)
            end
        end

        ::continue::
    end
end

return AISystem
