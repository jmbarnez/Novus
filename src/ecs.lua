-- ECS (Entity Component System) Core module
-- Provides the foundation for scalable game architecture
-- Designed for large games with many entities

local ECS = {}

-- Unique ID generator for entities
local nextEntityId = 1

-- Entity registry: entityId -> component table
local entities = {}

-- Component storage: componentType -> entityId -> componentData
local components = {}

-- System registry: systemName -> system table
local systems = {}

-- System execution order (deterministic)
local systemOrder = {
    "InputSystem",              -- Process input first
    "PhysicsSystem",            -- Apply physics after input
    "PhysicsCollisionSystem",   -- Handle all physics-based collisions (items, asteroids, etc)
    "CollisionSystem",          -- Special collisions (player-specific logic)
    "MagnetSystem",             -- Handle item attraction and collection
    "DestructionSystem",        -- Handle entity destruction
    "BoundarySystem",           -- Apply boundaries after physics
    "TrailSystem",              -- Update trails after movement
    "DebrisSystem",             -- Update debris particles
    "UISystem",                 -- Update UI (notifications, etc)
    "CameraSystem",             -- Update camera after all movement
    "RenderSystem"              -- Render world after all movement
}

-- Create a new entity
-- @return entityId number: Unique identifier for the entity
function ECS.createEntity()
    local entityId = nextEntityId
    nextEntityId = nextEntityId + 1

    entities[entityId] = {}
    print("Entity created with ID: " .. entityId)
    return entityId
end

-- Destroy an entity and all its components
-- @param entityId number: The entity to destroy
function ECS.destroyEntity(entityId)
    if not entities[entityId] then
        error("Attempted to destroy non-existent entity: " .. entityId)
    end

    -- Remove from all component types
    for componentType, _ in pairs(components) do
        components[componentType][entityId] = nil
    end

    entities[entityId] = nil
    print("Entity destroyed: " .. entityId)
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
    end

    components[componentType][entityId] = componentData
    entities[entityId][componentType] = true

    print("Component added - Entity: " .. entityId .. ", Type: " .. componentType)
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

    entities[entityId][componentType] = nil
    print("Component removed - Entity: " .. entityId .. ", Type: " .. componentType)
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

-- Get all entities with specific components (for system queries)
-- @param requiredComponents table: Array of component types that must be present
-- @return entities table: Array of entity IDs that have all required components
function ECS.getEntitiesWith(requiredComponents)
    if not requiredComponents or type(requiredComponents) ~= "table" then
        error("Invalid requiredComponents: " .. tostring(requiredComponents))
    end
    
    local result = {}

    for entityId, entityComponents in pairs(entities) do
        local hasAllComponents = true

        for _, componentType in ipairs(requiredComponents) do
            if not entityComponents[componentType] then
                hasAllComponents = false
                break
            end
        end

        if hasAllComponents then
            table.insert(result, entityId)
        end
    end

    return result
end

-- Register a system
-- @param systemName string: Name of the system
-- @param system table: System object with update/draw functions
function ECS.registerSystem(systemName, system)
    systems[systemName] = system
    print("System registered: " .. systemName)
end

-- Update all registered systems in deterministic order
-- @param dt number: Delta time since last update
function ECS.update(dt)
    -- Update systems in deterministic order
    for _, systemName in ipairs(systemOrder) do
        local system = systems[systemName]
        if system and system.update then
            system.update(dt)
        end
    end
end

-- Draw all registered systems in deterministic order
function ECS.draw()
    -- Draw systems in deterministic order
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

-- Clear all entities and components (useful for cleanup/testing)
function ECS.clear()
    entities = {}
    components = {}
    systems = {}
    nextEntityId = 1
    print("ECS cleared")
end

-- Debug function to print current state
function ECS.debug()
    print("=== ECS Debug Info ===")
    
    -- Count entities properly
    local entityCount = 0
    for _ in pairs(entities) do
        entityCount = entityCount + 1
    end
    print("Entities: " .. entityCount)
    
    -- Count component types properly
    local componentTypeCount = 0
    for _ in pairs(components) do
        componentTypeCount = componentTypeCount + 1
    end
    print("Component types: " .. componentTypeCount)
    
    -- Count systems properly
    local systemCount = 0
    for _ in pairs(systems) do
        systemCount = systemCount + 1
    end
    print("Systems: " .. systemCount)

    for componentType, entityComponents in pairs(components) do
        local count = 0
        for _ in pairs(entityComponents) do
            count = count + 1
        end
        print("  " .. componentType .. ": " .. count .. " entities")
    end
end

return ECS