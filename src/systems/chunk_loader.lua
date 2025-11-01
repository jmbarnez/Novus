---@diagnostic disable: undefined-global
-- Chunk Loader System - ensures nearby chunks are loaded and far chunks unloaded

local ECS = require('src.ecs')
local EntityHelpers = require('src.entity_helpers')
local WorldChunkManager = require('src.world_chunk_manager')

local ChunkLoaderSystem = {
    name = "ChunkLoaderSystem",
    priority = 1.5, -- Run early
}

local LOAD_RADIUS_CHUNKS = 1 -- how many chunks around player to keep loaded
local UNLOAD_RADIUS_CHUNKS = LOAD_RADIUS_CHUNKS + 1

function ChunkLoaderSystem.update(dt)
    local px, py = EntityHelpers.getPlayerPosition()
    if not px then return end

    -- Ensure chunks around player are loaded
    WorldChunkManager.ensureLoadedAround(px, py, LOAD_RADIUS_CHUNKS)

    -- Unload distant chunks
    local baseCx, baseCy = WorldChunkManager.worldToChunk(px, py)
    for key, chunk in pairs(WorldChunkManager.chunks) do
        if chunk and (math.abs(chunk.cx - baseCx) > UNLOAD_RADIUS_CHUNKS or math.abs(chunk.cy - baseCy) > UNLOAD_RADIUS_CHUNKS) then
            -- Unload chunk to free memory
            WorldChunkManager.unloadChunk(chunk.cx, chunk.cy)
        end
    end
end

return ChunkLoaderSystem


