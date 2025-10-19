---@diagnostic disable: undefined-global
-- AI System - Basic patrol and chase behaviors for enemy drones

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRange = require('src.systems.turret_range')
local Systems = {}

local AI = {
    name = "AISystem",
    priority = 9,
}

-- Simple helper for distance squared
local function distSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

-- Update loop: handle AI states
function AI.update(dt)
    -- Gather player position (assume single player-controlled drone)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local playerPos = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerPos = ECS.getComponent(input.targetEntity, "Position")
        end
    end

    -- Update all AI-controlled drones
    local enemyEntities = ECS.getEntitiesWith({"AIController", "Position", "Velocity", "Turret"})
    for _, eid in ipairs(enemyEntities) do
        local ai = ECS.getComponent(eid, "AIController")
        local pos = ECS.getComponent(eid, "Position")
        local vel = ECS.getComponent(eid, "Velocity")
        local turret = ECS.getComponent(eid, "Turret")
        local miningAI = ECS.getComponent(eid, "MiningAI")
        local combatAI = ECS.getComponent(eid, "CombatAI")
        if not (ai and pos and vel) then goto continue end

        -- Skip ALL AI processing for mining AI ships - they are handled by EnemyMiningSystem
        -- Check for MiningAI component FIRST to avoid any state changes
        if miningAI then
            print("[AISystem] Skipping miner " .. eid .. " - has MiningAI component")
            goto continue
        end

        -- Combat AI ships use this system for patrol/chase behavior
        -- CombatAI component is optional marker for clarity but not required for processing

        -- Calculate firing range based on turret module's projectile properties
        local fireRange = ai.fireRange
        if turret and turret.moduleName then
            fireRange = TurretRange.getMaxRange(turret.moduleName)
        end

        -- If player exists, check detection
        if playerPos then
            local dsq = distSq(pos.x, pos.y, playerPos.x, playerPos.y)
            -- Use much larger detection radius (further away), default 1000+ pixels
            local detectionRadiusSq = (ai.detectionRadius * ai.detectionRadius)
            
            if dsq < detectionRadiusSq then
                -- Switch to aggressive/chase state
                ai.state = "chase"
            else
                -- Return to patrol if not in detection range
                if ai.state == "chase" then
                    ai.state = "patrol"
                end
            end
        end

        if ai.state == "patrol" then
            -- Move along patrol points
            if #ai.patrolPoints > 0 then
                local target = ai.patrolPoints[ai.currentPoint]
                if not target then goto continue end
                local dx = target.x - pos.x
                local dy = target.y - pos.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < 10 then
                    ai.currentPoint = ai.currentPoint % #ai.patrolPoints + 1
                else
                    -- Normalize and set velocity toward point (simple behavior)
                    vel.vx = (dx / dist) * ai.speed
                    vel.vy = (dy / dist) * ai.speed
                end
            end
        elseif ai.state == "chase" and playerPos then
            -- Move toward player and potentially fire turret
            local dx = playerPos.x - pos.x
            local dy = playerPos.y - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Always move toward player when in chase state
            if dist > 0 then
                vel.vx = (dx / dist) * ai.speed
                vel.vy = (dy / dist) * ai.speed
            end
            
            -- Aim and fire turret at player if within firing range
            if turret and turret.moduleName and dist < fireRange then
                local TurretSystem = ECS.getSystem("TurretSystem")
                if TurretSystem and TurretSystem.fireTurret then
                    TurretSystem.fireTurret(eid, playerPos.x, playerPos.y)
                end
            end
        end

        ::continue::
    end
end

return AI
