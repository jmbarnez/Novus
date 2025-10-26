---@diagnostic disable: undefined-global
-- Entity Pool System - Reuses entity objects instead of creating/destroying
-- Significantly reduces GC pressure and allocation overhead

local ECS = require('src.ecs')
local Components = require('src.components')

local EntityPool = {
    pools = {
        -- pool_name = {
        --     available = {id1, id2, ...},  -- Available entities
        --     inUse = {id1, id2, ...},      -- Currently in use
        --     factory = function() end,     -- Creates new entity with components
        --     reset = function(id) end,     -- Resets entity for reuse
        --     maxSize = 100,                -- Max pool size
        -- }
    }
}

-- Register a pool for a specific entity type
-- factory: function that returns a new entity ID with all components
-- reset: function that resets an entity for reuse (clears specific components)
-- maxSize: maximum number of pooled entities
function EntityPool.registerPool(poolName, factory, reset, maxSize)
    maxSize = maxSize or 100
    
    EntityPool.pools[poolName] = {
        available = {},
        inUse = {},
        factory = factory,
        reset = reset,
        maxSize = maxSize,
        stats = {
            created = 0,
            reused = 0,
            destroyed = 0,
        }
    }
end

-- Get an entity from the pool or create a new one
function EntityPool.acquire(poolName)
    local pool = EntityPool.pools[poolName]
    if not pool then
        error(string.format("Pool '%s' not registered", poolName))
    end
    
    local entityId
    
    if #pool.available > 0 then
        -- Reuse from pool
        entityId = table.remove(pool.available)
        pool.reset(entityId)  -- Reset the entity
        pool.stats.reused = pool.stats.reused + 1
    else
        -- Create new entity
        entityId = pool.factory()
        pool.stats.created = pool.stats.created + 1
    end
    
    table.insert(pool.inUse, entityId)
    return entityId
end

-- Return an entity to the pool
-- @return boolean: true if the entity was reclaimed, false if it was not managed by this pool
function EntityPool.release(poolName, entityId)
    local pool = EntityPool.pools[poolName]
    if not pool then
        error(string.format("Pool '%s' not registered", poolName))
    end

    -- Find and remove from inUse
    local wasInUse = false
    for i, id in ipairs(pool.inUse) do
        if id == entityId then
            table.remove(pool.inUse, i)
            wasInUse = true
            break
        end
    end

    if not wasInUse then
        -- Prevent duplicate entries in the available list when an entity is
        -- released multiple times or was never acquired from this pool.
        return false
    end

    -- Add back to available if pool not full
    if #pool.available < pool.maxSize then
        table.insert(pool.available, entityId)
    else
        -- Pool is full, destroy the entity
        ECS.destroyEntity(entityId)
        pool.stats.destroyed = pool.stats.destroyed + 1
    end

    return true
end

-- Get pool statistics
function EntityPool.getStats(poolName)
    local pool = EntityPool.pools[poolName]
    if not pool then return nil end
    
    return {
        poolName = poolName,
        available = #pool.available,
        inUse = #pool.inUse,
        stats = pool.stats,
    }
end

-- Print all pool statistics
function EntityPool.printStats()
    print("\n=== Entity Pool Statistics ===")
    for poolName, pool in pairs(EntityPool.pools) do
        local stats = EntityPool.getStats(poolName)
        if stats then
            print(string.format("  %s: Available=%d, InUse=%d, Created=%d, Reused=%d, Destroyed=%d",
                poolName, stats.available, stats.inUse, 
                pool.stats.created, pool.stats.reused, pool.stats.destroyed))
        end
    end
    print("")
end

-- Clear all pools (useful on scene reload)
function EntityPool.clearAll()
    for poolName, pool in pairs(EntityPool.pools) do
        for _, entityId in ipairs(pool.available) do
            ECS.destroyEntity(entityId)
        end
        for _, entityId in ipairs(pool.inUse) do
            ECS.destroyEntity(entityId)
        end
        pool.available = {}
        pool.inUse = {}
    end
end

return EntityPool
