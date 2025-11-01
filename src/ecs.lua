-- ECS (Entity Component System) Core module
-- Provides the foundation for scalable game architecture
-- Designed for large games with many entities

local ECS = {}

-- Custom serialization handlers per component type
local componentSerializers = {}
local componentDeserializers = {}

-- Unique ID generator for entities
local nextEntityId = 1

-- Entity registry: entityId -> component table
local entities = {}

-- Component storage: componentType -> entityId -> componentData
local components = {}

-- Component index: componentType -> { entityId = true, ... } (set of entity IDs)
-- Enables O(n) queries instead of O(nm)
local componentIndex = {}

-- Newly created entities that received a Position component this frame
local newPositionEntities = {}

-- Recycled entity ID pool (to prevent overflow in long-running games)
local recycledEntityIds = {}

-- System registry: systemName -> system table
local systems = {}

-- System execution order is now determined by system priority
local systemOrder = nil -- Will be computed after all systems are registered

-- Utility: deep copy tables while skipping functions/userdata
local function deepCopy(value, visited)
    local valueType = type(value)
    if valueType ~= "table" then
        if valueType == "function" or valueType == "userdata" or valueType == "thread" then
            return nil
        end
        return value
    end

    visited = visited or {}
    if visited[value] then
        return visited[value]
    end

    local copy = {}
    visited[value] = copy

    for k, v in pairs(value) do
        local newKey = deepCopy(k, visited)
        local newValue = deepCopy(v, visited)
        if newKey ~= nil and newValue ~= nil then
            copy[newKey] = newValue
        end
    end

    return copy
end

-- Allow systems/components to provide custom serialization logic
function ECS.registerComponentSerializer(componentType, handlers)
    if type(componentType) ~= "string" then
        error("componentType must be a string")
    end
    handlers = handlers or {}
    if handlers.serialize and type(handlers.serialize) ~= "function" then
        error("serialize handler must be a function")
    end
    if handlers.deserialize and type(handlers.deserialize) ~= "function" then
        error("deserialize handler must be a function")
    end
    componentSerializers[componentType] = handlers.serialize
    componentDeserializers[componentType] = handlers.deserialize
end

-- Create a new entity
-- @return entityId number: Unique identifier for the entity
function ECS.createEntity()
    local entityId
    
    -- Reuse recycled IDs if available to prevent overflow
    if next(recycledEntityIds) then
        entityId = table.remove(recycledEntityIds)
    else
        entityId = nextEntityId
        nextEntityId = nextEntityId + 1
    end

    entities[entityId] = {}
    -- Main checkpoint log: entity creation (optional, comment out for less spam)
    -- print("Entity created with ID: " .. entityId)
    return entityId
end

-- Destroy an entity and all its components
-- @param entityId number: The entity to destroy
function ECS.destroyEntity(entityId)
    if not entities[entityId] then
        -- Silently ignore attempts to destroy non-existent entities
        -- This prevents crashes from double-destruction scenarios
        return
    end

    -- Remove from all component types and indices
    for componentType, _ in pairs(components) do
        components[componentType][entityId] = nil
        if componentIndex[componentType] then
            componentIndex[componentType][entityId] = nil
        end
    end

    entities[entityId] = nil
    
    -- Recycle the entity ID for reuse (prevents overflow in long sessions)
    table.insert(recycledEntityIds, entityId)
    
    -- Main checkpoint log: entity destruction (optional, comment out for less spam)
    -- print("Entity destroyed: " .. entityId)
end

-- Add a component to an entity
-- @param entityId number: The entity to add the component to
-- @param componentType string: The type of component
-- @param componentData table: The component data
function ECS.addComponent(entityId, componentType, componentData)
    if not entityId or type(entityId) ~= "number" then
        error("Invalid entity ID: " .. tostring(entityId))
    end
    
    if not componentType or type(componentType) ~= "string" then
        error("Invalid component type: " .. tostring(componentType))
    end
    
    if not componentData or type(componentData) ~= "table" then
        error("Invalid component data for " .. componentType .. ": " .. tostring(componentData))
    end
    
    if not entities[entityId] then
        error("Attempted to add component to non-existent entity: " .. entityId)
    end

    if not components[componentType] then
        components[componentType] = {}
        componentIndex[componentType] = {}
    end

    components[componentType][entityId] = componentData
    entities[entityId][componentType] = true
    componentIndex[componentType][entityId] = true

    -- Track newly positioned entities for efficient chunk registration
    if componentType == "Position" then
        table.insert(newPositionEntities, entityId)
    end

    -- print("Component added - Entity: " .. entityId .. ", Type: " .. componentType)
end

-- Consume and return entities that recently received a Position component
-- Clears the internal list so callers get only new entries since last call
function ECS.consumeNewPositionEntities()
    local list = newPositionEntities
    newPositionEntities = {}
    return list
end

-- Remove a component from an entity
-- @param entityId number: The entity to remove from
-- @param componentType string: The type of component to remove
function ECS.removeComponent(entityId, componentType)
    if not entities[entityId] then
        return -- Entity doesn't exist, nothing to do
    end

    if components[componentType] then
        components[componentType][entityId] = nil
    end

    if componentIndex[componentType] then
        componentIndex[componentType][entityId] = nil
    end

    entities[entityId][componentType] = nil
    -- print("Component removed - Entity: " .. entityId .. ", Type: " .. componentType)
end

-- Get a component from an entity
-- @param entityId number: The entity to get from
-- @param componentType string: The type of component to get
-- @return componentData table or nil: The component data if it exists
function ECS.getComponent(entityId, componentType)
    if not entityId or type(entityId) ~= "number" then
        error("Invalid entity ID: " .. tostring(entityId))
    end
    
    if not componentType or type(componentType) ~= "string" then
        error("Invalid component type: " .. tostring(componentType))
    end
    
    if not components[componentType] then
        return nil
    end
    return components[componentType][entityId]
end

-- Get all components of a specific type for an entity
-- @param entityId number: The entity to get components from
-- @param componentType string: The type of component to get
-- @return table: An array of component data tables. Returns an empty table if none found.
function ECS.getComponents(entityId, componentType)
    if not entityId or type(entityId) ~= "number" then
        error("Invalid entity ID: " .. tostring(entityId))
    end
    
    if not componentType or type(componentType) ~= "string" then
        error("Invalid component type: " .. tostring(componentType))
    end
    
    local results = {}
    -- The current ECS design stores only one component of each type per entity.
    -- If multiple 'Renderable' components are desired (for layered drawing), 
    -- the component storage mechanism would need to be re-evaluated.
    -- For now, this function will return the single component if it exists, 
    -- or an empty table if not.
    local component = components[componentType] and components[componentType][entityId]
    if component then
        table.insert(results, component)
    end
    return results
end

-- Check if an entity has a component
-- @param entityId number: The entity to check
-- @param componentType string: The type of component to check for
-- @return boolean: True if entity has the component
function ECS.hasComponent(entityId, componentType)
    if not entityId or type(entityId) ~= "number" then
        return false
    end
    
    if not componentType or type(componentType) ~= "string" then
        return false
    end
    
    return entities[entityId] and entities[entityId][componentType] == true
end

-- Helper function to count table entries
local function countTable(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Internal: compute intersection of two entity sets
-- @param set1 table: Set of entity IDs (table with entityId = true)
-- @param set2 table: Set of entity IDs (table with entityId = true)
-- @return table: Array of entity IDs in both sets
local function intersectSets(set1, set2)
    local result = {}
    -- Iterate over the smaller set for better performance
    local smaller, larger = set1, set2
    if next(set2) == nil or (next(set1) ~= nil and countTable(set1) > countTable(set2)) then
        smaller, larger = set2, set1
    end

    for entityId, _ in pairs(smaller) do
        if larger[entityId] then
            table.insert(result, entityId)
        end
    end
    return result
end

-- Get all entities with specific components (for system queries)
-- Optimized with O(n) complexity using indexed component sets and intersection
-- @param requiredComponents table: Array of component types that must be present
-- @return entities table: Array of entity IDs that have all required components
function ECS.getEntitiesWith(requiredComponents)
    if not requiredComponents or type(requiredComponents) ~= "table" then
        error("Invalid requiredComponents: " .. tostring(requiredComponents))
    end
    
    if #requiredComponents == 0 then
        return {}
    end
    
    -- Start with entities that have the first component type
    local result = {}
    local firstComponentType = requiredComponents[1]
    
    if not componentIndex[firstComponentType] then
        return {}
    end
    
    -- If only one component type, convert set to array
    if #requiredComponents == 1 then
        for entityId, _ in pairs(componentIndex[firstComponentType]) do
            table.insert(result, entityId)
        end
        return result
    end
    
    -- Build initial set from first component
    local currentSet = componentIndex[firstComponentType]
    
    -- Intersect with remaining component types
    for i = 2, #requiredComponents do
        local componentType = requiredComponents[i]
        if not componentIndex[componentType] then
            return {} -- No entities have this component type
        end
        
        -- Create result array from intersection
        local newResult = {}
        for entityId, _ in pairs(currentSet) do
            if componentIndex[componentType][entityId] then
                table.insert(newResult, entityId)
            end
        end
        
        if #newResult == 0 then
            return {} -- No entities satisfy all requirements
        end
        
        -- Convert back to set for next iteration if needed
        if i < #requiredComponents then
            currentSet = {}
            for _, entityId in ipairs(newResult) do
                currentSet[entityId] = true
            end
        else
            result = newResult
        end
    end
    
    return result
end

-- Register a system
-- @param systemName string: Name of the system
-- @param system table: System object with update/draw functions

-- Register a system with optional priority (lower runs first)
function ECS.registerSystem(systemName, system)
    systems[systemName] = system
    system.name = systemName
    -- print("System registered: " .. systemName)
    systemOrder = nil -- Invalidate cached order
end

-- Internal: compute system order by priority (lower runs first)
local function computeSystemOrder()
    local systemList = {}
    for name, sys in pairs(systems) do
        sys.name = name
        table.insert(systemList, sys)
    end
    table.sort(systemList, function(a, b)
        local pa = a.priority or 1000
        local pb = b.priority or 1000
        if pa == pb then
            return (a.name or "") < (b.name or "")
        end
        return pa < pb
    end)
    local order = {}
    for _, sys in ipairs(systemList) do
        table.insert(order, sys.name)
    end
    return order
end

-- Update all registered systems in deterministic order
-- @param dt number: Delta time since last update
function ECS.update(dt)
    if not systemOrder then
        systemOrder = computeSystemOrder()
    end
    for _, systemName in ipairs(systemOrder) do
        local system = systems[systemName]
        if system and system.update then
            system.update(dt)
        end
    end
end

-- Draw all registered systems in deterministic order
function ECS.draw()
    if not systemOrder then
        systemOrder = computeSystemOrder()
    end
    for _, systemName in ipairs(systemOrder) do
        local system = systems[systemName]
        if system and system.draw then
            system.draw()
        end
    end
end

-- Get system by name
-- @param systemName string: Name of the system to get
-- @return system table or nil: The system if it exists
function ECS.getSystem(systemName)
    return systems[systemName]
end

-- Get all components of a specific entity
-- @param entityId number: The entity to get components from
-- @return table: Array of {componentType, componentData} pairs
function ECS.getEntityComponents(entityId)
    if not entityId or type(entityId) ~= "number" then
        error("Invalid entity ID: " .. tostring(entityId))
    end
    
    if not entities[entityId] then
        return {}
    end
    
    local results = {}
    
    -- Iterate through all component types for this entity
    for componentType, _ in pairs(components) do
        if components[componentType][entityId] then
            table.insert(results, {
                type = componentType,
                data = components[componentType][entityId]
            })
        end
    end
    
    return results
end

-- Clear all entities and components (useful for cleanup/testing)
function ECS.clear()
    entities = {}
    components = {}
    componentIndex = {}
    systems = {}
    nextEntityId = 1
    recycledEntityIds = {}
    systemOrder = nil
    -- print("ECS cleared")
end

-- Debug function to print current state
function ECS.debug()
    -- print("=== ECS Debug Info ===")
    
    -- Count entities properly
    local entityCount = 0
    for _ in pairs(entities) do
        entityCount = entityCount + 1
    end
    -- print("Entities: " .. entityCount)
    
    -- Count component types properly
    local componentTypeCount = 0
    for _ in pairs(components) do
        componentTypeCount = componentTypeCount + 1
    end
    -- print("Component types: " .. componentTypeCount)
    
    -- Count systems properly
    local systemCount = 0
    for _ in pairs(systems) do
        systemCount = systemCount + 1
    end
    -- print("Systems: " .. systemCount)

    for componentType, entityComponents in pairs(components) do
        local count = 0
        for _ in pairs(entityComponents) do
            count = count + 1
        end
    -- print("  " .. componentType .. ": " .. count .. " entities")
    end
end

function ECS.debugCanvasEntities()
    local canvasCount = 0
    for entityId, entityComponents in pairs(entities) do
        if entityComponents["Canvas"] then
            canvasCount = canvasCount + 1
            print("Canvas entity found: " .. entityId)
        end
    end
    print("Total Canvas entities: " .. canvasCount)
end

-- Serialize the ECS state into a plain Lua table
function ECS.serialize()
    local state = {
        nextEntityId = nextEntityId,
        recycledEntityIds = deepCopy(recycledEntityIds),
        entities = {},
    }

    for entityId, componentSet in pairs(entities) do
        local entityComponents = {}
        for componentType in pairs(componentSet) do
            local componentStore = components[componentType]
            if componentStore then
                local componentData = componentStore[entityId]
                if componentData then
                    local serializer = componentSerializers[componentType]
                    local serialized
                    if serializer then
                        serialized = serializer(entityId, componentData)
                    else
                        serialized = deepCopy(componentData)
                    end
                    if serialized ~= nil then
                        entityComponents[componentType] = serialized
                    end
                end
            end
        end
        if next(entityComponents) ~= nil then
            state.entities[entityId] = entityComponents
        end
    end

    return state
end

-- Restore ECS state from serialized data
function ECS.deserialize(state)
    if type(state) ~= "table" then
        error("Invalid ECS state: expected table")
    end

    entities = {}
    components = {}
    componentIndex = {}
    nextEntityId = state.nextEntityId or 1
    recycledEntityIds = deepCopy(state.recycledEntityIds or {}) or {}

    for entityId, componentMap in pairs(state.entities or {}) do
        local numericId = tonumber(entityId) or entityId
        entities[numericId] = {}
        for componentType, componentData in pairs(componentMap) do
            if not components[componentType] then
                components[componentType] = {}
                componentIndex[componentType] = {}
            end

            local deserializer = componentDeserializers[componentType]
            local restored
            if deserializer then
                restored = deserializer(numericId, componentData)
            else
                restored = deepCopy(componentData)
            end

            if restored ~= nil then
                components[componentType][numericId] = restored
                componentIndex[componentType][numericId] = true
                entities[numericId][componentType] = true
            end
        end
    end

    systemOrder = nil
end

-- Register AI blackboard components (MiningTarget, CombatTarget, AttackOrder)
do
    local aiBlackboard = require('src.components.ai_blackboard')
    -- These are simple data components, no custom serialization needed for now
    ECS.registerComponentSerializer('MiningTarget', {})
    ECS.registerComponentSerializer('CombatTarget', {})
    ECS.registerComponentSerializer('AttackOrder', {})
end

return ECS