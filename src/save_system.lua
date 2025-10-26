-- Save/Load System - Handles game state persistence
-- Serializes and deserializes ECS entities, components, and game progress

local SaveSystem = {}
local ECS = require('src.ecs')
local Components = require('src.components')

-- Configuration
SaveSystem.saveVersion = "1.0" -- Increment when save format changes
SaveSystem.autoSaveInterval = 300 -- Auto-save every 5 minutes
SaveSystem.maxSaveSlots = 3
SaveSystem.saveDirectory = "saves"

-- Component serializers - convert components to/from serializable data
local ComponentSerializers = {}

-- Position component
ComponentSerializers.Position = {
    serialize = function(comp)
        return {x = comp.x, y = comp.y, prevX = comp.prevX, prevY = comp.prevY}
    end,
    deserialize = function(data)
        return Components.Position(data.x, data.y)
    end
}

-- Velocity component
ComponentSerializers.Velocity = {
    serialize = function(comp)
        return {vx = comp.vx, vy = comp.vy}
    end,
    deserialize = function(data)
        return Components.Velocity(data.vx, data.vy)
    end
}

-- Physics component
ComponentSerializers.Physics = {
    serialize = function(comp)
        return {friction = comp.friction, mass = comp.mass, angularDamping = comp.angularDamping}
    end,
    deserialize = function(data)
        return Components.Physics(data.friction, data.mass, data.angularDamping)
    end
}

-- Hull component
ComponentSerializers.Hull = {
    serialize = function(comp)
        return {current = comp.current, max = comp.max}
    end,
    deserialize = function(data)
        return Components.Hull(data.current, data.max)
    end
}

-- Shield component
ComponentSerializers.Shield = {
    serialize = function(comp)
        return {current = comp.current, max = comp.max, regen = comp.regen, regenDelay = comp.regenDelay, regenTimer = comp.regenTimer}
    end,
    deserialize = function(data)
        return Components.Shield(data.current, data.max, data.regen, data.regenDelay)
    end
}

-- Energy component
ComponentSerializers.Energy = {
    serialize = function(comp)
        return {current = comp.current, max = comp.max, regenRate = comp.regenRate}
    end,
    deserialize = function(data)
        return Components.Energy(data.current, data.max, data.regenRate)
    end
}

-- Cargo component (complex - contains items table)
ComponentSerializers.Cargo = {
    serialize = function(comp)
        return {items = comp.items, capacity = comp.capacity, currentVolume = comp.currentVolume}
    end,
    deserialize = function(data)
        return Components.Cargo(data.items, data.capacity)
    end
}

-- Wallet component
ComponentSerializers.Wallet = {
    serialize = function(comp)
        return {credits = comp.credits}
    end,
    deserialize = function(data)
        return Components.Wallet(data.credits)
    end
}

-- Skills component (complex - contains nested skill data)
ComponentSerializers.Skills = {
    serialize = function(comp)
        return {skills = comp.skills}
    end,
    deserialize = function(data)
        return Components.Skills()
    end
}

-- AI component
ComponentSerializers.AI = {
    serialize = function(comp)
        return {
            type = comp.type,
            state = comp.state,
            detectionRadius = comp.detectionRadius,
            patrolPoints = comp.patrolPoints,
            currentPoint = comp.currentPoint,
            spawnX = comp.spawnX,
            spawnY = comp.spawnY,
            _wanderAngle = comp._wanderAngle,
            _wanderTimer = comp._wanderTimer,
            orbitDirection = comp.orbitDirection,
            _swingAngle = comp._swingAngle,
            _swingTimer = comp._swingTimer,
            aggressiveTimer = comp.aggressiveTimer,
            lastAttacker = comp.lastAttacker,
            aggressiveDuration = comp.aggressiveDuration
        }
    end,
    deserialize = function(data)
        return Components.AI(data)
    end
}

-- Asteroid component
ComponentSerializers.Asteroid = {
    serialize = function(comp)
        return {asteroidType = comp.asteroidType, crystalFormation = comp.crystalFormation, xpReward = comp.xpReward}
    end,
    deserialize = function(data)
        return Components.Asteroid(data.asteroidType, data.crystalFormation, data.xpReward)
    end
}

-- Station component
ComponentSerializers.Station = {
    serialize = function(comp)
        return {}
    end,
    deserialize = function(data)
        return Components.Station()
    end
}

-- QuestBoard component
ComponentSerializers.QuestBoard = {
    serialize = function(comp)
        return {stationId = comp.stationId, quests = comp.quests, lastGenerationTime = comp.lastGenerationTime, generationInterval = comp.generationInterval}
    end,
    deserialize = function(data)
        return Components.QuestBoard(data.stationId)
    end
}

-- WarpGate component
ComponentSerializers.WarpGate = {
    serialize = function(comp)
        return {destination = comp.destination, active = comp.active, showRepairTooltip = comp.showRepairTooltip}
    end,
    deserialize = function(data)
        return Components.WarpGate(data)
    end
}

-- Wreckage component
ComponentSerializers.Wreckage = {
    serialize = function(comp)
        return {sourceShip = comp.sourceShip}
    end,
    deserialize = function(data)
        return Components.Wreckage(data.sourceShip)
    end
}

-- Item component
ComponentSerializers.Item = {
    serialize = function(comp)
        return {id = comp.id, def = comp.def}
    end,
    deserialize = function(data)
        local ItemDefs = require('src.items.item_loader')
        return {id = data.id, def = ItemDefs[data.id]}
    end
}

-- Stack component
ComponentSerializers.Stack = {
    serialize = function(comp)
        return {quantity = comp.quantity}
    end,
    deserialize = function(data)
        return Components.Stack(data.quantity)
    end
}

-- Renderable component
ComponentSerializers.Renderable = {
    serialize = function(comp)
        return {shape = comp.shape, width = comp.width, height = comp.height, radius = comp.radius, color = comp.color, texture = comp.texture}
    end,
    deserialize = function(data)
        return Components.Renderable(data.shape, data.width, data.height, data.radius, data.color, data.texture)
    end
}

-- Collidable component
ComponentSerializers.Collidable = {
    serialize = function(comp)
        return {radius = comp.radius}
    end,
    deserialize = function(data)
        return Components.Collidable(data.radius)
    end
}

-- PolygonShape component
ComponentSerializers.PolygonShape = {
    serialize = function(comp)
        return {vertices = comp.vertices, rotation = comp.rotation, prevRotation = comp.prevRotation}
    end,
    deserialize = function(data)
        return Components.PolygonShape(data.vertices, data.rotation)
    end
}

-- AngularVelocity component
ComponentSerializers.AngularVelocity = {
    serialize = function(comp)
        return {omega = comp.omega}
    end,
    deserialize = function(data)
        return Components.AngularVelocity(data.omega)
    end
}

-- RotationalMass component
ComponentSerializers.RotationalMass = {
    serialize = function(comp)
        return {inertia = comp.inertia}
    end,
    deserialize = function(data)
        return Components.RotationalMass(data.inertia)
    end
}

-- Force component
ComponentSerializers.Force = {
    serialize = function(comp)
        return {fx = comp.fx, fy = comp.fy, torque = comp.torque}
    end,
    deserialize = function(data)
        return Components.Force(data.fx, data.fy, data.torque)
    end
}

-- Acceleration component
ComponentSerializers.Acceleration = {
    serialize = function(comp)
        return {ax = comp.ax, ay = comp.ay}
    end,
    deserialize = function(data)
        return Components.Acceleration(data.ax, data.ay)
    end
}

-- InputControlled component
ComponentSerializers.InputControlled = {
    serialize = function(comp)
        return {
            controlType = comp.controlType,
            speed = comp.speed,
            targetEntity = comp.targetEntity,
            targetedEnemy = comp.targetedEnemy,
            targetingTarget = comp.targetingTarget,
            targetingProgress = comp.targetingProgress,
            targetingStartTime = comp.targetingStartTime
        }
    end,
    deserialize = function(data)
        return Components.InputControlled(data.controlType, data.speed)
    end
}

-- ControlledBy component
ComponentSerializers.ControlledBy = {
    serialize = function(comp)
        return {pilotId = comp.pilotId}
    end,
    deserialize = function(data)
        return Components.ControlledBy(data.pilotId)
    end
}

-- Camera component
ComponentSerializers.Camera = {
    serialize = function(comp)
        return {width = comp.width, height = comp.height, smoothing = comp.smoothing, zoom = comp.zoom, targetZoom = comp.targetZoom}
    end,
    deserialize = function(data)
        return Components.Camera(data.width, data.height, data.smoothing, data.zoom)
    end
}

-- CameraTarget component
ComponentSerializers.CameraTarget = {
    serialize = function(comp)
        return {priority = comp.priority, smoothing = comp.smoothing}
    end,
    deserialize = function(data)
        return Components.CameraTarget(data.priority, data.smoothing)
    end
}

-- Player component
ComponentSerializers.Player = {
    serialize = function(comp)
        return {}
    end,
    deserialize = function(data)
        return Components.Player()
    end
}

-- Level component
ComponentSerializers.Level = {
    serialize = function(comp)
        return {level = comp.level}
    end,
    deserialize = function(data)
        return Components.Level(data.level)
    end
}

-- Initialize save system
function SaveSystem.init()
    -- Create saves directory if it doesn't exist
    if love.filesystem then
        love.filesystem.createDirectory(SaveSystem.saveDirectory)
    end
end

-- Serialize an entity and all its components
function SaveSystem.serializeEntity(entityId)
    local entityData = {
        id = entityId,
        components = {}
    }

    -- Get all components for this entity
    local components = ECS.getEntityComponents(entityId)
    for _, compData in ipairs(components) do
        local compType = compData.type
        local serializer = ComponentSerializers[compType]

        if serializer then
            entityData.components[compType] = serializer.serialize(compData.data)
        else
            -- Unknown component type - save as generic table
            entityData.components[compType] = compData.data
        end
    end

    return entityData
end

-- Deserialize an entity and recreate it with all components
function SaveSystem.deserializeEntity(entityData)
    local entityId = ECS.createEntity()

    for compType, compData in pairs(entityData.components) do
        local serializer = ComponentSerializers[compType]

        if serializer then
            local component = serializer.deserialize(compData)
            ECS.addComponent(entityId, compType, component)
        else
            -- Unknown component type - try to recreate as-is
            ECS.addComponent(entityId, compType, compData)
        end
    end

    return entityId
end

-- Save game state to file
function SaveSystem.saveGame(slot)
    slot = slot or 1

    if not love.filesystem then
        print("Save system not available - no filesystem access")
        return false
    end

    local saveData = {
        version = SaveSystem.saveVersion,
        timestamp = os.time(),
        entities = {},
        gameState = {
            playerId = nil,
            cameraId = nil,
            currentWorld = nil
        }
    }

    -- Find player and camera entities
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        saveData.gameState.playerId = playerEntities[1]
    end

    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        saveData.gameState.cameraId = cameraEntities[1]
    end

    -- Save all entities
    for entityId in pairs(ECS.entities) do
        local entityData = SaveSystem.serializeEntity(entityId)
        table.insert(saveData.entities, entityData)
    end

    -- Convert to JSON and save
    local json = require("dkjson") -- You'll need to add this dependency
    local jsonString = json.encode(saveData, {indent = true})

    local filename = string.format("%s/save_%d.json", SaveSystem.saveDirectory, slot)
    local success = love.filesystem.write(filename, jsonString)

    if success then
        print("Game saved to slot " .. slot)
        return true
    else
        print("Failed to save game to slot " .. slot)
        return false
    end
end

-- Load game state from file
function SaveSystem.loadGame(slot)
    slot = slot or 1

    if not love.filesystem then
        print("Save system not available - no filesystem access")
        return false
    end

    local filename = string.format("%s/save_%d.json", SaveSystem.saveDirectory, slot)
    local fileInfo = love.filesystem.getInfo(filename)

    if not fileInfo then
        print("No save file found for slot " .. slot)
        return false
    end

    -- Read and parse save data
    local jsonString = love.filesystem.read(filename)
    local json = require("dkjson")
    local saveData = json.decode(jsonString)

    if not saveData then
        print("Failed to parse save file for slot " .. slot)
        return false
    end

    -- Check version compatibility
    if saveData.version ~= SaveSystem.saveVersion then
        print("Save file version mismatch. Expected: " .. SaveSystem.saveVersion .. ", Found: " .. saveData.version)
        -- You could implement version migration here
        return false
    end

    -- Clear current game state
    ECS.clear()

    -- Recreate all entities
    for _, entityData in ipairs(saveData.entities) do
        SaveSystem.deserializeEntity(entityData)
    end

    print("Game loaded from slot " .. slot)
    return true
end

-- Get list of available save slots
function SaveSystem.getSaveSlots()
    local slots = {}

    if not love.filesystem then
        return slots
    end

    for i = 1, SaveSystem.maxSaveSlots do
        local filename = string.format("%s/save_%d.json", SaveSystem.saveDirectory, i)
        local fileInfo = love.filesystem.getInfo(filename)

        if fileInfo then
            local jsonString = love.filesystem.read(filename)
            local json = require("dkjson")
            local saveData = json.decode(jsonString)

            table.insert(slots, {
                slot = i,
                timestamp = saveData and saveData.timestamp,
                exists = true
            })
        else
            table.insert(slots, {
                slot = i,
                exists = false
            })
        end
    end

    return slots
end

-- Delete a save slot
function SaveSystem.deleteSave(slot)
    slot = slot or 1

    if not love.filesystem then
        return false
    end

    local filename = string.format("%s/save_%d.json", SaveSystem.saveDirectory, slot)
    return love.filesystem.remove(filename)
end

-- Auto-save functionality
function SaveSystem.update(dt)
    if not SaveSystem.autoSaveTimer then
        SaveSystem.autoSaveTimer = 0
    end

    SaveSystem.autoSaveTimer = SaveSystem.autoSaveTimer + dt

    if SaveSystem.autoSaveTimer >= SaveSystem.autoSaveInterval then
        SaveSystem.saveGame(0) -- Use slot 0 for auto-save
        SaveSystem.autoSaveTimer = 0
    end
end

return SaveSystem
