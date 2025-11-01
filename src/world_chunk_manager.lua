-- World Chunk Manager
-- Manages fixed-size world chunks (load/unload, lookup, registration)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Procedural = require('src.procedural')

local WorldChunkManager = {
    chunks = {}, -- key -> chunk table
    seed = nil,
}

-- Local deep copy utility (skips functions/userdata)
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

-- Initialize chunk manager with optional world configuration (uses seed when provided)
function WorldChunkManager.init(worldConfig)
    WorldChunkManager.chunks = {}
    WorldChunkManager.seed = worldConfig and worldConfig.seed or os.time()
    -- Ensure procedural templates initialized
    if Procedural and Procedural.init then
        Procedural.init()
    end
end

-- Convert world coords to chunk coords
function WorldChunkManager.worldToChunk(x, y)
    return Constants.worldToChunk(x, y)
end

-- Chunk key helper
function WorldChunkManager.chunkKey(cx, cy)
    return Constants.chunkKey(cx, cy)
end

-- Get existing chunk or nil
function WorldChunkManager.getChunk(cx, cy)
    local key = WorldChunkManager.chunkKey(cx, cy)
    return WorldChunkManager.chunks[key]
end

-- Create an empty chunk table (does not generate content)
function WorldChunkManager.createEmptyChunk(cx, cy)
    local key = WorldChunkManager.chunkKey(cx, cy)
    local chunk = {
        cx = cx,
        cy = cy,
        key = key,
        entities = {}, -- entity ids owned by this chunk
        generated = false,
    }
    WorldChunkManager.chunks[key] = chunk
    return chunk
end

-- Register an existing entity to a chunk (adds a Chunk component)
function WorldChunkManager.registerEntityToChunk(entityId, cx, cy)
    local chunk = WorldChunkManager.getChunk(cx, cy) or WorldChunkManager.createEmptyChunk(cx, cy)
    table.insert(chunk.entities, entityId)
    -- Attach Chunk component so other systems can inspect ownership
    ECS.addComponent(entityId, "Chunk", { cx = cx, cy = cy })
end

-- Load (or generate) a chunk at cx,cy
-- This function is deterministic based on seed + coords and will create entities and register them
function WorldChunkManager.loadChunk(cx, cy)
    local key = WorldChunkManager.chunkKey(cx, cy)
    local existing = WorldChunkManager.chunks[key]
    if existing and existing.generated then
        return existing
    end

    local chunk = existing or WorldChunkManager.createEmptyChunk(cx, cy)

    -- Deterministic seeding per-chunk (note: this alters global RNG state briefly)
    local seed = (WorldChunkManager.seed or 0) + cx * 73856093 + cy * 19349663
    math.randomseed(seed)

    -- Attempt to load persisted chunk file from disk (if present)
    if love and love.filesystem and love.filesystem.getInfo then
        local SaveLoad = require('src.save_load')
        local WorldLoader = require('src.world_loader')
        local worldId = WorldLoader.getCurrentWorldId() or 'global'
        local dir = 'saves/chunks'
        local path = dir .. '/' .. tostring(worldId) .. '_' .. key .. '.lua'
        if love.filesystem.getInfo(path) then
            local chunkChunk = love.filesystem.load(path)
            if chunkChunk then
                local ok, data = pcall(chunkChunk)
                if ok and data and data.savedEntities then
                    chunk.savedEntities = data.savedEntities
                end
            end
        end
    end

    -- If we have saved entity data for this chunk (persisted), restore it instead of regenerating
    if chunk.savedEntities and #chunk.savedEntities > 0 then
        for _, compMap in ipairs(chunk.savedEntities) do
            local eid = ECS.createEntity()
            for compType, compData in pairs(compMap) do
                local restored = deepCopy(compData)
                ECS.addComponent(eid, compType, restored)
            end
            WorldChunkManager.registerEntityToChunk(eid, cx, cy)
            local pos = ECS.getComponent(eid, "Position")
            local coll = ECS.getComponent(eid, "Collidable")
            if pos and coll then
                local SpawnCollisionUtils = require('src.spawn_collision_utils')
                SpawnCollisionUtils.registerEntity(eid, pos.x, pos.y, coll.radius, "restored")
            end
        end
        chunk.savedEntities = nil -- clear saved data after restore
    else
        -- No random asteroid spawning in chunks - asteroids only spawn in configured clusters
        -- Chunks are now only used for persistence and loading saved entities
    end

    chunk.generated = true
    return chunk
end

-- Unload a chunk: destroy owned entities and unregister them
function WorldChunkManager.unloadChunk(cx, cy)
    local chunk = WorldChunkManager.getChunk(cx, cy)
    if not chunk then return false end

    -- Persist entity components into chunk file on disk and free memory
    chunk.savedEntities = {}
    for i = #chunk.entities, 1, -1 do
        local eid = chunk.entities[i]
        -- Collect components for persistence
        local comps = ECS.getEntityComponents(eid) -- returns array of {type, data}
        local compMap = {}
        for _, entry in ipairs(comps) do
            compMap[entry.type] = deepCopy(entry.data)
        end
        table.insert(chunk.savedEntities, compMap)

        -- Unregister from spawn registry and destroy runtime entity
        local SpawnCollisionUtils = require('src.spawn_collision_utils')
        SpawnCollisionUtils.unregisterEntity(eid)
        ECS.destroyEntity(eid)
        table.remove(chunk.entities, i)
    end

    -- Write chunk.savedEntities to disk
    if love and love.filesystem and love.filesystem.write then
        local SaveLoad = require('src.save_load')
        local WorldLoader = require('src.world_loader')
        local worldId = WorldLoader.getCurrentWorldId() or 'global'
        local dir = 'saves/chunks'
        love.filesystem.createDirectory(dir)
        local path = dir .. '/' .. tostring(worldId) .. '_' .. key .. '.lua'
        local snapshot = { savedEntities = chunk.savedEntities, meta = { cx = cx, cy = cy, world = worldId } }
        local contents = SaveLoad.snapshotToString(snapshot)
        local ok, err = pcall(function()
            love.filesystem.write(path, contents)
        end)
        -- clear savedEntities from memory after persisting to disk
        chunk.savedEntities = nil
    end

    -- Keep chunk record but mark as not generated (so it can be restored later)
    chunk.generated = false
    return true
end

-- Ensure chunks are loaded around a world position (radius in chunks)
function WorldChunkManager.ensureLoadedAround(x, y, radiusInChunks)
    radiusInChunks = radiusInChunks or 1
    local baseCx, baseCy = WorldChunkManager.worldToChunk(x, y)
    local loaded = {}
    for dx = -radiusInChunks, radiusInChunks do
        for dy = -radiusInChunks, radiusInChunks do
            local cx = baseCx + dx
            local cy = baseCy + dy
            WorldChunkManager.loadChunk(cx, cy)
            table.insert(loaded, WorldChunkManager.chunkKey(cx, cy))
        end
    end
    return loaded
end

-- Get neighbor chunk keys for a given chunk
function WorldChunkManager.getNeighborChunks(cx, cy)
    local neighbors = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                table.insert(neighbors, WorldChunkManager.chunkKey(cx + dx, cy + dy))
            end
        end
    end
    return neighbors
end

return WorldChunkManager


