---@diagnostic disable: undefined-global
-- Chunk Debug - draws chunk boundaries on the map and optionally in world

local WorldChunkManager = require('src.world_chunk_manager')
local Constants = require('src.constants')
local ECS = require('src.ecs')

local ChunkDebug = {
    -- Use the chunk manager flag if present, otherwise local
}

function ChunkDebug.isEnabled()
    return (WorldChunkManager and WorldChunkManager.debugOverlayEnabled) == true
end

function ChunkDebug.setEnabled(v)
    if WorldChunkManager then
        WorldChunkManager.debugOverlayEnabled = v
    end
end

-- Draw chunk grid on a MapWindow instance (expects MapWindow to have _mapX/_mapY/_mapW/_mapH/_scale/panX/panY)
function ChunkDebug.drawOnMap(mapWindow)
    if not mapWindow then return end
    local mapX, mapY, mapW, mapH = mapWindow._mapX, mapWindow._mapY, mapWindow._mapW, mapWindow._mapH
    local scale = mapWindow._scale or mapWindow._baseScale or 1
    local panX = mapWindow.panX or 0
    local panY = mapWindow.panY or 0

    -- Compute world bounds visible in this map
    local minX = mapWindow._minX or (panX - (mapW/2)/scale)
    local maxX = mapWindow._maxX or (panX + (mapW/2)/scale)
    local minY = mapWindow._minY or (panY - (mapH/2)/scale)
    local maxY = mapWindow._maxY or (panY + (mapH/2)/scale)

    local cs = Constants.CHUNK_SIZE or 5000
    -- Compute chunk index range and clamp to world chunk indices
    local maxCx = math.floor(Constants.world_width / cs) - 1
    local maxCy = math.floor(Constants.world_height / cs) - 1
    local cx1 = math.max(0, math.floor(minX / cs))
    local cy1 = math.max(0, math.floor(minY / cs))
    -- Use (maxX - 1) so an exact boundary at world_max_x doesn't create an extra chunk
    local cx2 = math.min(maxCx, math.floor((maxX - 1) / cs))
    local cy2 = math.min(maxCy, math.floor((maxY - 1) / cs))

    -- Helper: world -> map coords
    local centerX = mapX + mapW / 2
    local centerY = mapY + mapH / 2
    local function worldToMap(wx, wy)
        return centerX + (wx - panX) * scale, centerY + (wy - panY) * scale
    end

    love.graphics.setLineWidth(1)
    for cx = cx1, cx2 do
        for cy = cy1, cy2 do
            local wx = cx * cs
            local wy = cy * cs
            local wx2 = wx + cs
            local wy2 = wy + cs
            local mx1, my1 = worldToMap(wx, wy)
            local mx2, my2 = worldToMap(wx2, wy2)
            local w = mx2 - mx1
            local h = my2 - my1

            -- Color based on loaded state
            local chunk = WorldChunkManager and WorldChunkManager.getChunk and WorldChunkManager.getChunk(cx, cy)
            if chunk and (chunk.generated or (chunk.savedEntities and #chunk.savedEntities > 0)) then
                love.graphics.setColor(0, 1, 0, 0.6) -- loaded -> green
            else
                love.graphics.setColor(1, 1, 1, 0.18) -- unloaded -> faint white
            end
            love.graphics.rectangle('line', mx1, my1, w, h)

            -- Draw chunk coords label small
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(tostring(cx) .. ',' .. tostring(cy), mx1 + 2, my1 + 2)
        end
    end
end

return ChunkDebug


