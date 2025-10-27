-- ECS AI Blackboard Components
-- These are simple component definitions for AI state sharing

local components = {}

-- MiningTarget: { asteroid = entityId }
components.MiningTarget = function(data)
    return { asteroid = data.asteroid }
end

-- CombatTarget: { target = entityId }
components.CombatTarget = function(data)
    return { target = data.target }
end

-- AttackOrder: { target = entityId }
components.AttackOrder = function(data)
    return { target = data.target }
end

return components
