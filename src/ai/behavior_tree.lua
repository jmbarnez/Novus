-- Enhanced ECS-compatible Behavior Tree implementation with unified state management
-- Usage: Attach a BehaviorTree component to an entity with a root node
-- Integrates with AIState component for centralized state tracking and error handling

local ECS = require('src.ecs')
local AIStateManager = require('src.systems.ai_state_manager')

local BehaviorTree = {}
BehaviorTree.__index = BehaviorTree

-- Node status
BehaviorTree.SUCCESS = 1
BehaviorTree.FAILURE = 2
BehaviorTree.RUNNING = 3

-- Base node with error handling
function BehaviorTree.createNode(def)
    local node = setmetatable(def, { __index = BehaviorTree })
    node.executionCount = 0
    node.lastExecutionTime = 0
    node.errorCount = 0
    return node
end

-- Sequence node: runs children in order until one fails
function BehaviorTree.sequence(children)
    return BehaviorTree.createNode({
        type = "sequence",
        children = children,
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            for i, child in ipairs(self.children) do
                local success, status = pcall(function()
                    return child:tick(entity, dt)
                end)

                if not success then
                    self.errorCount = self.errorCount + 1
                    AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Sequence child " .. i .. " failed: " .. tostring(status))
                    return BehaviorTree.FAILURE
                end

                if status ~= BehaviorTree.SUCCESS then
                    return status
                end
            end
            return BehaviorTree.SUCCESS
        end
    })
end

-- Selector node: runs children in order until one succeeds
function BehaviorTree.selector(children)
    return BehaviorTree.createNode({
        type = "selector",
        children = children,
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            for i, child in ipairs(self.children) do
                local success, status = pcall(function()
                    return child:tick(entity, dt)
                end)

                if not success then
                    self.errorCount = self.errorCount + 1
                    AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Selector child " .. i .. " failed: " .. tostring(status))
                    -- Continue to next child instead of failing completely
                elseif status == BehaviorTree.SUCCESS then
                    return BehaviorTree.SUCCESS
                elseif status == BehaviorTree.RUNNING then
                    return BehaviorTree.RUNNING
                end
            end
            return BehaviorTree.FAILURE
        end
    })
end

-- Leaf/action node with state integration
function BehaviorTree.action(fn)
    return BehaviorTree.createNode({
        type = "action",
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            local success, result = pcall(fn, entity, dt)
            if not success then
                self.errorCount = self.errorCount + 1
                AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Action failed: " .. tostring(result))
                return BehaviorTree.FAILURE
            end

            return result
        end
    })
end

-- Decorator node: modifies the behavior of a child node
function BehaviorTree.decorator(child, decoratorFn)
    return BehaviorTree.createNode({
        type = "decorator",
        child = child,
        decoratorFn = decoratorFn,
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            local success, status = pcall(function()
                return self.decoratorFn(self.child, entity, dt)
            end)

            if not success then
                self.errorCount = self.errorCount + 1
                AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Decorator failed: " .. tostring(status))
                return BehaviorTree.FAILURE
            end

            return status
        end
    })
end

-- Condition node: checks a condition and returns success/failure
function BehaviorTree.condition(conditionFn)
    return BehaviorTree.createNode({
        type = "condition",
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            local success, result = pcall(conditionFn, entity, dt)
            if not success then
                self.errorCount = self.errorCount + 1
                AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Condition failed: " .. tostring(result))
                return BehaviorTree.FAILURE
            end

            return result and BehaviorTree.SUCCESS or BehaviorTree.FAILURE
        end
    })
end

-- Parallel node: runs all children simultaneously
function BehaviorTree.parallel(children, successPolicy, failurePolicy)
    successPolicy = successPolicy or "one"  -- "one" or "all"
    failurePolicy = failurePolicy or "one"  -- "one" or "all"

    return BehaviorTree.createNode({
        type = "parallel",
        children = children,
        successPolicy = successPolicy,
        failurePolicy = failurePolicy,
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            local successCount = 0
            local failureCount = 0
            local runningCount = 0

            for i, child in ipairs(self.children) do
                local success, status = pcall(function()
                    return child:tick(entity, dt)
                end)

                if not success then
                    self.errorCount = self.errorCount + 1
                    AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Parallel child " .. i .. " failed: " .. tostring(status))
                    failureCount = failureCount + 1
                elseif status == BehaviorTree.SUCCESS then
                    successCount = successCount + 1
                elseif status == BehaviorTree.FAILURE then
                    failureCount = failureCount + 1
                elseif status == BehaviorTree.RUNNING then
                    runningCount = runningCount + 1
                end
            end

            -- Check failure policy
            if self.failurePolicy == "one" and failureCount > 0 then
                return BehaviorTree.FAILURE
            elseif self.failurePolicy == "all" and failureCount == #self.children then
                return BehaviorTree.FAILURE
            end

            -- Check success policy
            if self.successPolicy == "one" and successCount > 0 then
                return BehaviorTree.SUCCESS
            elseif self.successPolicy == "all" and successCount == #self.children then
                return BehaviorTree.SUCCESS
            end

            -- If any children are running, return running
            if runningCount > 0 then
                return BehaviorTree.RUNNING
            end

            -- Default to running if no clear success/failure
            return BehaviorTree.RUNNING
        end
    })
end

-- Performance monitoring and caching
BehaviorTree.nodeCache = {}
BehaviorTree.cacheSize = 100

-- Cache frequently used nodes
function BehaviorTree.getCachedNode(key, constructor, ...)
    if not BehaviorTree.nodeCache[key] then
        BehaviorTree.nodeCache[key] = constructor(...)
        -- Maintain cache size limit
        local cacheCount = 0
        for _ in pairs(BehaviorTree.nodeCache) do cacheCount = cacheCount + 1 end
        if cacheCount > BehaviorTree.cacheSize then
            -- Simple LRU eviction - remove random entry
            local toRemove
            for k in pairs(BehaviorTree.nodeCache) do
                toRemove = k
                break
            end
            BehaviorTree.nodeCache[toRemove] = nil
        end
    end
    return BehaviorTree.nodeCache[key]
end

-- Optimized parallel execution with early exit
function BehaviorTree.parallel(children, successPolicy, failurePolicy)
    successPolicy = successPolicy or "one"  -- "one" or "all"
    failurePolicy = failurePolicy or "one"  -- "one" or "all"

    return BehaviorTree.createNode({
        type = "parallel",
        children = children,
        successPolicy = successPolicy,
        failurePolicy = failurePolicy,
        tick = function(self, entity, dt)
            self.executionCount = self.executionCount + 1
            self.lastExecutionTime = love.timer.getTime()

            local successCount = 0
            local failureCount = 0
            local runningCount = 0

            -- Early exit optimizations
            for i, child in ipairs(self.children) do
                local success, status = pcall(function()
                    return child:tick(entity, dt)
                end)

                if not success then
                    self.errorCount = self.errorCount + 1
                    AIStateManager.setError(entity, "BEHAVIOR_ERROR", "Parallel child " .. i .. " failed: " .. tostring(status))
                    failureCount = failureCount + 1

                    -- Early failure exit if policy allows
                    if self.failurePolicy == "one" then
                        return BehaviorTree.FAILURE
                    end
                elseif status == BehaviorTree.SUCCESS then
                    successCount = successCount + 1

                    -- Early success exit if policy allows
                    if self.successPolicy == "one" then
                        return BehaviorTree.SUCCESS
                    end
                elseif status == BehaviorTree.FAILURE then
                    failureCount = failureCount + 1

                    -- Early failure exit if policy allows
                    if self.failurePolicy == "one" then
                        return BehaviorTree.FAILURE
                    end
                elseif status == BehaviorTree.RUNNING then
                    runningCount = runningCount + 1
                end
            end

            -- Check final policies
            if self.failurePolicy == "all" and failureCount == #self.children then
                return BehaviorTree.FAILURE
            elseif self.successPolicy == "all" and successCount == #self.children then
                return BehaviorTree.SUCCESS
            elseif runningCount > 0 then
                return BehaviorTree.RUNNING
            end

            -- Default to running if no clear success/failure
            return BehaviorTree.RUNNING
        end
    })
end

-- Memory-efficient node pooling (optional advanced optimization)
BehaviorTree.nodePool = {}
BehaviorTree.poolEnabled = false

function BehaviorTree.getPooledNode(nodeType, ...)
    if not BehaviorTree.poolEnabled then
        return BehaviorTree[nodeType](...)
    end

    local pool = BehaviorTree.nodePool[nodeType]
    if pool and #pool > 0 then
        local node = table.remove(pool)
        -- Reinitialize node
        node.executionCount = 0
        node.errorCount = 0
        node.lastExecutionTime = 0
        return node
    end

    return BehaviorTree[nodeType](...)
end

function BehaviorTree.returnToPool(node)
    if not BehaviorTree.poolEnabled or not node.type then return end

    local pool = BehaviorTree.nodePool[node.type]
    if not pool then
        pool = {}
        BehaviorTree.nodePool[node.type] = pool
    end

    -- Limit pool size
    if #pool < 50 then
        table.insert(pool, node)
    end
end

return BehaviorTree
