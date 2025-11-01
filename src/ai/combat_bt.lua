-- Combat AI Behavior Tree definition
local BehaviorTree = require('src.ai.behavior_tree')

-- Example action nodes (replace with real logic)

local ECS = require('src.ecs')

-- Blackboard: store target (e.g., player) as a component
local function findTarget(entity, dt)
    local pos = ECS.getComponent(entity, "Position")
    if not pos then return BehaviorTree.FAILURE end
    -- Find player's ship (has ControlledBy component)
    local playerShips = ECS.getEntitiesWith({"ControlledBy", "Position"})
    local closest, closestDistSq = nil, math.huge
    for _, shipId in ipairs(playerShips) do
        local shipPos = ECS.getComponent(shipId, "Position")
        if shipPos then
            local dx, dy = shipPos.x - pos.x, shipPos.y - pos.y
            local distSq = dx*dx + dy*dy
            if distSq < closestDistSq then
                closest, closestDistSq = shipId, distSq
            end
        end
    end
    if closest then
        -- Respect AI detection radius (don't chase from across the map)
        local aiComp = ECS.getComponent(entity, "AI")
        local detectionRadius = nil
        if aiComp and aiComp.detectionRadius then
            detectionRadius = aiComp.detectionRadius
        else
            -- Try design fallback
            local shipDesign = ECS.getComponent(entity, "ShipDesign")
            local ShipLoader = require('src.ship_loader')
            local design = shipDesign and ShipLoader.getDesign(shipDesign.designId)
            detectionRadius = design and (design.combatDetectionRange or design.detectionRange) or nil
        end

        if detectionRadius then
            local dist = math.sqrt(closestDistSq)
            if dist <= detectionRadius then
                ECS.addComponent(entity, "CombatTarget", { target = closest })
                return BehaviorTree.SUCCESS
            else
                ECS.removeComponent(entity, "CombatTarget")
                return BehaviorTree.FAILURE
            end
        else
            -- No detection radius info: be conservative and require a reasonable default
            local Constants = require('src.constants')
            if math.sqrt(closestDistSq) <= (Constants.ai_detection_radius or 1200) then
                ECS.addComponent(entity, "CombatTarget", { target = closest })
                return BehaviorTree.SUCCESS
            else
                ECS.removeComponent(entity, "CombatTarget")
                return BehaviorTree.FAILURE
            end
        end
    else
        ECS.removeComponent(entity, "CombatTarget")
        return BehaviorTree.FAILURE
    end
end

local function moveToTarget(entity, dt)
    local pos = ECS.getComponent(entity, "Position")
    local vel = ECS.getComponent(entity, "Velocity")
    local combatTarget = ECS.getComponent(entity, "CombatTarget")
    if not (pos and vel and combatTarget and combatTarget.target) then return BehaviorTree.FAILURE end
    local targetPos = ECS.getComponent(combatTarget.target, "Position")
    if not targetPos then return BehaviorTree.FAILURE end
    local dx, dy = targetPos.x - pos.x, targetPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    local targetDistance = 200
    if dist <= targetDistance then
        return BehaviorTree.SUCCESS
    end

    -- Use the steering-aware AI behaviors so the ship cannot instantly change direction
    local Behaviors = require('src.systems.ai_behaviors')
    local aiComp = ECS.getComponent(entity, "AI")
    local turret = ECS.getComponent(entity, "Turret")
    local shipDesign = ECS.getComponent(entity, "ShipDesign")
    local ShipLoader = require('src.ship_loader')
    local design = shipDesign and ShipLoader.getDesign(shipDesign.designId) or {}

    -- Delegate movement to the Chase behavior which respects steeringResponsiveness
    Behaviors.Chase.update(entity, aiComp or {}, pos, vel, turret, design or {}, targetPos, dt)
    return BehaviorTree.RUNNING
end

local function attackTarget(entity, dt)
    local combatTarget = ECS.getComponent(entity, "CombatTarget")
    if not (combatTarget and combatTarget.target) then return BehaviorTree.FAILURE end
    -- Example: set a flag/component to fire weapons at target
    ECS.addComponent(entity, "AttackOrder", { target = combatTarget.target })
    -- Could check for line of sight, weapon cooldown, etc.
    return BehaviorTree.RUNNING
end

-- Patrol behavior - fallback when no target is detected
local function patrol(entity, dt)
    local ai = ECS.getComponent(entity, "AI")
    local pos = ECS.getComponent(entity, "Position")
    local vel = ECS.getComponent(entity, "Velocity")
    local turret = ECS.getComponent(entity, "Turret")
    
    if not (ai and pos and vel) then return BehaviorTree.FAILURE end
    
    -- Get ship design for movement parameters (via ShipDesign component)
    local shipDesign = ECS.getComponent(entity, "ShipDesign")
    local ShipLoader = require('src.ship_loader')
    local design = shipDesign and ShipLoader.getDesign(shipDesign.designId) or {}
    
    -- Initialize spawn position if not set
    if not ai.spawnX or not ai.spawnY then
        ai.spawnX = pos.x
        ai.spawnY = pos.y
    end
    
    -- Use the Patrol behavior from ai_behaviors
    local Behaviors = require('src.systems.ai_behaviors')
    Behaviors.Patrol.update(entity, ai, pos, vel, turret, design, dt)
    return BehaviorTree.RUNNING
end

-- Build the combat behavior tree with patrol fallback
-- Uses selector: try combat sequence, if it fails fall back to patrol
local combatTree = BehaviorTree.selector({
    -- Try to find target and engage
    BehaviorTree.sequence({
        BehaviorTree.action(findTarget),
        BehaviorTree.action(moveToTarget),
        BehaviorTree.action(attackTarget)
    }),
    -- Fall back to patrol if no target found
    BehaviorTree.action(patrol)
})

return combatTree
