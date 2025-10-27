-- Behavior Tree System: runs all entities with a BehaviorTree component
-- Integrated with AIState for unified state management and error handling
local ECS = require('src.ecs')
local BehaviorTree = require('src.ai.behavior_tree')
local AIStateManager = require('src.systems.ai_state_manager')

local BehaviorTreeSystem = {
    name = "BehaviorTreeSystem",
    priority = 5
}

function BehaviorTreeSystem.update(dt)
    local entities = ECS.getEntitiesWith({"BehaviorTree"})
    for _, entityId in ipairs(entities) do
        local btComp = ECS.getComponent(entityId, "BehaviorTree")
        local aiState = ECS.getComponent(entityId, "AIState")

        if btComp and btComp.root then
            -- Ensure AIState component exists
            if not aiState then
                AIStateManager.initializeEntity(entityId)
                aiState = ECS.getComponent(entityId, "AIState")
            end

            -- Skip execution if in error state (let AIStateManager handle recovery)
            if aiState and aiState.currentState == AIStateManager.STATES.ERROR then
                goto continue
            end

            -- Execute behavior tree with error handling
            local success, status = pcall(function()
                return btComp.root:tick(entityId, dt)
            end)

            if not success then
                AIStateManager.setError(entityId, "BEHAVIOR_TREE_ERROR", "BT execution failed: " .. tostring(status))
            end
        end

        ::continue::
    end
end

return BehaviorTreeSystem
