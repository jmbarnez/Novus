---@diagnostic disable: undefined-global
-- Chunk Registry System
-- Ensures entities with Position are assigned a Chunk component when spawned

local ECS = require('src.ecs')
local WorldChunkManager = require('src.world_chunk_manager')

local ChunkRegistrySystem = {
    name = "ChunkRegistrySystem",
    priority = 1.6, -- Run after chunk loader
}

function ChunkRegistrySystem.update(dt)
    -- On first run, register any pre-existing entities (one-time full scan)
    ChunkRegistrySystem._initialized = ChunkRegistrySystem._initialized or false
    if not ChunkRegistrySystem._initialized then
        local candidates = ECS.getEntitiesWith({"Position"})
        for _, eid in ipairs(candidates) do
            if not ECS.hasComponent(eid, "Chunk") then
                local pos = ECS.getComponent(eid, "Position")
                if pos then
                    local cx, cy = WorldChunkManager.worldToChunk(pos.x, pos.y)
                    WorldChunkManager.registerEntityToChunk(eid, cx, cy)
                end
            end
        end
        ChunkRegistrySystem._initialized = true
        return
    end

    -- After initialization, only process entities that just received a Position component
    local newEntities = ECS.consumeNewPositionEntities()
    for _, eid in ipairs(newEntities) do
        if not ECS.hasComponent(eid, "Chunk") then
            local pos = ECS.getComponent(eid, "Position")
            if pos then
                local cx, cy = WorldChunkManager.worldToChunk(pos.x, pos.y)
                WorldChunkManager.registerEntityToChunk(eid, cx, cy)
            end
        end
    end
end

return ChunkRegistrySystem


