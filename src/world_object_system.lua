-- World Object System
-- Handles spawning and management of reusable world objects (stations, landmarks, etc.)

local WorldObjectSystem = {
    objectTemplates = {},
    loadedObjects = {}
}

-- Load all world object templates from the world_objects directory
function WorldObjectSystem.loadAllTemplates()
    local modulePrefix = "src.world_objects"
    local fsPath = "src/world_objects"
    local loadedCount = 0

    local lfs = love and love.filesystem
    if lfs and lfs.getDirectoryItems then
        local entries = lfs.getDirectoryItems(fsPath)
        table.sort(entries)

        for _, entry in ipairs(entries) do
            if entry:sub(-4) == ".lua" then
                local info = lfs.getInfo(fsPath .. "/" .. entry, "file")
                if info and info.type == "file" then
                    local objectName = entry:sub(1, -5)
                    if objectName ~= "init" and objectName ~= "" then
                        local filepath = modulePrefix .. "." .. objectName
                        local success, template = pcall(require, filepath)
                        if success and template then
                            WorldObjectSystem.objectTemplates[objectName] = template
                            loadedCount = loadedCount + 1
                        end
                    end
                end
            end
        end
    end

    return loadedCount
end

-- Get a world object template by name
function WorldObjectSystem.getTemplate(templateName)
    return WorldObjectSystem.objectTemplates[templateName]
end

-- Spawn a world object at specified coordinates
-- @param templateName string: Name of the object template to spawn
-- @param x number: X position to spawn at
-- @param y number: Y position to spawn at
-- @param overrideData table: Optional data to override template defaults
-- @return number: Entity ID of spawned object, or nil if failed
function WorldObjectSystem.spawnWorldObject(templateName, x, y, overrideData)
    local template = WorldObjectSystem.getTemplate(templateName)
    if not template then
        print("World object template not found: " .. tostring(templateName))
        return nil
    end

    -- Merge template with override data
    local spawnData = {}
    for key, value in pairs(template) do
        spawnData[key] = value
    end
    
    if overrideData then
        for key, value in pairs(overrideData) do
            spawnData[key] = value
        end
    end
    
    -- Set position
    spawnData.x = x or spawnData.x or 0
    spawnData.y = y or spawnData.y or 0

    -- Generate the station entity using the procedural system
    local Procedural = require('src.procedural')
    local stationComponents = Procedural.generateEntity('station', spawnData)
    
    if not stationComponents then
        print("Failed to generate station components for template: " .. templateName)
        return nil
    end
    
    -- Create the entity in ECS
    local ECS = require('src.ecs')
    local entityId = ECS.createEntity()
    for componentType, componentData in pairs(stationComponents) do
        ECS.addComponent(entityId, componentType, componentData)
    end
    
    -- Track the loaded object
    WorldObjectSystem.loadedObjects[entityId] = {
        templateName = templateName,
        template = template,
        spawnData = spawnData
    }
    
    print("Spawned world object: " .. templateName .. " at (" .. x .. ", " .. y .. ")")
    return entityId
end

-- Spawn multiple world objects using a template with collision avoidance
-- @param templateName string: Name of the object template to spawn
-- @param count number: Number of objects to spawn
-- @param spawnStrategy string: Strategy for positioning ("random", "cluster", "grid")
-- @param strategyData table: Configuration for the spawn strategy
-- @return table: Array of entity IDs that were successfully spawned
function WorldObjectSystem.spawnMultipleWorldObjects(templateName, count, spawnStrategy, strategyData)
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local spawnedEntities = {}
    local entityRadius = 100  -- Default collision radius for world objects
    local minDistance = 400  -- Minimum distance between object centers
    
    for i = 1, count do
        local spawnData = WorldObjectSystem.calculateSpawnPosition(spawnStrategy, strategyData, i)
        local maxAttempts = 30  -- Try up to 30 times to find a valid spawn position
        local attempts = 0
        local validPosition = false
        
        while attempts < maxAttempts and not validPosition do
            -- Use universal collision detection to check if position is safe
            validPosition = SpawnCollisionUtils.isPositionSafe(
                spawnData.x, 
                spawnData.y, 
                entityRadius, 
                minDistance, 
                {}  -- no excluded types
            )
            
            -- If position is invalid, try a new random position
            if not validPosition then
                spawnData = WorldObjectSystem.calculateSpawnPosition(spawnStrategy, strategyData, i)
                attempts = attempts + 1
            end
        end
        
        -- Only spawn if we found a valid position
        if validPosition then
            local entityId = WorldObjectSystem.spawnWorldObject(templateName, spawnData.x, spawnData.y)
            if entityId then
                table.insert(spawnedEntities, entityId)
            end
        end
    end
    
    return spawnedEntities
end

-- Calculate spawn position based on strategy
-- @param strategy string: Spawn strategy name
-- @param data table: Strategy configuration
-- @param index number: Entity index (for grid patterns)
-- @return table: Spawn data with position
function WorldObjectSystem.calculateSpawnPosition(strategy, data, index)
    local spawnData = {
        x = 0,
        y = 0,
        angle = 0
    }
    
    if strategy == "random" then
        -- Random position in world bounds
        local Constants = require('src.constants')
        spawnData.x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
        spawnData.y = Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y)
        spawnData.angle = math.random() * 2 * math.pi
        
    elseif strategy == "cluster" then
        -- Random position within cluster radius
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * (data.radius or 1000)
        spawnData.x = (data.centerX or 0) + math.cos(angle) * distance
        spawnData.y = (data.centerY or 0) + math.sin(angle) * distance
        spawnData.angle = math.random() * 2 * math.pi
        
    elseif strategy == "grid" then
        -- Grid pattern
        local cols = data.cols or math.ceil(math.sqrt(count or 1))
        local spacing = data.spacing or 1000
        local row = math.floor((index - 1) / cols)
        local col = (index - 1) % cols
        spawnData.x = (data.startX or 0) + col * spacing
        spawnData.y = (data.startY or 0) + row * spacing
        spawnData.angle = math.random() * 2 * math.pi
    end
    
    return spawnData
end

-- Remove a spawned world object
-- @param entityId number: Entity ID to remove
function WorldObjectSystem.removeWorldObject(entityId)
    if WorldObjectSystem.loadedObjects[entityId] then
        WorldObjectSystem.loadedObjects[entityId] = nil
        
        -- Remove from ECS
        local ECS = require('src.ecs')
        ECS.destroyEntity(entityId)
        
        return true
    end
    
    return false
end

-- Get information about all loaded world objects
function WorldObjectSystem.getLoadedObjects()
    local objects = {}
    for entityId, data in pairs(WorldObjectSystem.loadedObjects) do
        table.insert(objects, {
            entityId = entityId,
            templateName = data.templateName,
            name = data.template.name,
            description = data.template.description
        })
    end
    return objects
end

-- Get a specific loaded world object
function WorldObjectSystem.getWorldObject(entityId)
    return WorldObjectSystem.loadedObjects[entityId]
end

-- Initialize the world object system
function WorldObjectSystem.init()
    local loaded = WorldObjectSystem.loadAllTemplates()
    print("Loaded " .. loaded .. " world object templates")
    return loaded
end

return WorldObjectSystem