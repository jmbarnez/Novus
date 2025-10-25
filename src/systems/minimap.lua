---@diagnostic disable: undefined-global
-- Minimap System
-- Draws a circular minimap with player, asteroids, and items
-- Uses batched rendering for performance

local ECS = require('src.ecs')
local BatchRenderer = require('src.ui.batch_renderer')
local Scaling = require('src.scaling')
local Constants = require('src.constants')
local EntityHelpers = require('src.entity_helpers')

local Minimap = {}
-- Radar-style minimap: show only a region around the player
local minimapWorldRadius = 800  -- Area (in world units) shown on minimap; adjust for desired radar range

-- Config
local BASE_MINIMAP_RADIUS = 80
local BASE_MINIMAP_MARGIN = 20
local minimapWorldScale = 0.25   -- Visual scale of the world on the minimap (1.0 = actual size)
local minimapX, minimapY = 0, 0
local minimapRadius = BASE_MINIMAP_RADIUS
local minimapMargin = BASE_MINIMAP_MARGIN
local _lastMinimapRadius = nil
local _lastMinimapX, _lastMinimapY = nil, nil

function Minimap._buildBlipCache(minimapX, minimapY, minimapRadius, playerX, playerY, radiusScale)
    radiusScale = radiusScale or 1
    local edgePadding = 20 * radiusScale
    local minR2 = (minimapRadius - edgePadding) ^ 2 -- margin for blips on edge
    local maxR2 = minimapRadius ^ 2
    local blips = {asteroids = {}, items = {}, enemies = {}, player = nil, boundary = nil}

    -- Asteroids
    for _, id in ipairs(ECS.getEntitiesWith({ 'Asteroid', 'Position', 'PolygonShape' })) do
        local pos = ECS.getComponent(id, 'Position')
        local poly = ECS.getComponent(id, 'PolygonShape')
        if pos and poly and poly.vertices then
            local dx, dy = pos.x - playerX, pos.y - playerY
            local scale = minimapRadius / minimapWorldRadius
            local mx, my = minimapX + dx * scale, minimapY + dy * scale
            -- Estimate asteroid radius from polygon vertices
            local estRadius = 0
            for _, v in ipairs(poly.vertices) do
                local r = math.sqrt(v.x * v.x + v.y * v.y)
                if r > estRadius then estRadius = r end
            end
            local blipRadius = math.max(2, estRadius * scale)
            -- Transform polygon vertices to minimap space
            local transformedVertices = {}
            local rot = poly.rotation or 0
            for _, v in ipairs(poly.vertices) do
                -- Scale and rotate vertex
                local localX = v.x * math.cos(rot) - v.y * math.sin(rot)
                local localY = v.x * math.sin(rot) + v.y * math.cos(rot)
                -- Apply minimap scale and offset
                table.insert(transformedVertices, mx + localX * scale)
                table.insert(transformedVertices, my + localY * scale)
            end
            table.insert(blips.asteroids, {mx, my, transformedVertices, blipRadius})
        end
    end

    -- Items
    for _, id in ipairs(ECS.getEntitiesWith({ 'Item', 'Position' })) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local dx, dy = pos.x - playerX, pos.y - playerY
            local scale = minimapRadius / minimapWorldRadius
            local mx, my = minimapX + dx * scale, minimapY + dy * scale
            local blipRadius = math.max(2, 1.5 * radiusScale) -- Ensure minimum size for visibility
            table.insert(blips.items, {mx, my, blipRadius})
        end
    end

    -- Enemies - use helper function for consistent detection
    local enemyShips = EntityHelpers.getEnemyShips()
    
    for _, id in ipairs(enemyShips) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local dx, dy = pos.x - playerX, pos.y - playerY
            local scale = minimapRadius / minimapWorldRadius
            local mx, my = minimapX + dx * scale, minimapY + dy * scale
            local blipRadius = math.max(3, 2 * radiusScale) -- Ensure minimum size for visibility
            table.insert(blips.enemies, {mx, my, blipRadius})
        end
    end

    -- World boundary
    local scale = minimapRadius / minimapWorldRadius
    local worldCenterX = minimapX - playerX * scale
    local worldCenterY = minimapY - playerY * scale
    local boundaryRadius = Constants.WORLD_RADIUS * scale
    blips.boundary = {worldCenterX, worldCenterY, boundaryRadius}

    blips.player = {minimapX, minimapY}
    -- You can similarly cache boundaries or other objects if desired.
    return blips
end

function Minimap.draw()
    local scaleX = Scaling.canvasScaleX or 1
    local scaleY = Scaling.canvasScaleY or 1
    local scaleU = math.min(scaleX, scaleY)
    local offsetX = Scaling.canvasOffsetX or 0
    local offsetY = Scaling.canvasOffsetY or 0

    local marginX = BASE_MINIMAP_MARGIN * scaleX
    local marginY = BASE_MINIMAP_MARGIN * scaleY
    local baseRadius = BASE_MINIMAP_RADIUS * scaleU
    minimapRadius = math.max(48, baseRadius)

    local screenRight = Scaling.REFERENCE_WIDTH
    minimapX = screenRight - marginX - minimapRadius
    minimapY = marginY + minimapRadius

    if _lastMinimapX ~= minimapX or _lastMinimapY ~= minimapY or _lastMinimapRadius ~= minimapRadius then
        _lastMinimapX = minimapX
        _lastMinimapY = minimapY
        _lastMinimapRadius = minimapRadius
    end

    -- Draw minimap background and border (queued for batch rendering)
    BatchRenderer.queueCircle(minimapX, minimapY, minimapRadius, 0, 0, 0, 1.0) -- fill
    BatchRenderer.queueCircleLine(minimapX, minimapY, minimapRadius, 1, 1, 1, 0.7) -- line

    -- Get player position and velocity using helper functions
    local playerX, playerY = EntityHelpers.getPlayerPosition()

    local radiusScale = minimapRadius / math.max(baseRadius, 1e-6)
    -- Always rebuild minimap cache every frame (no throttling)
    local cachedBlips = Minimap._buildBlipCache(minimapX, minimapY, minimapRadius, playerX, playerY, radiusScale)
    
    -- Render from cache (batched):
    if cachedBlips then
        -- Asteroid blips (gray)
        local asteroidColor = {0.7, 0.7, 0.7, 1}
        for _, p in ipairs(cachedBlips.asteroids) do
            local mx, my, transformedVertices, blipRadius = p[1], p[2], p[3], p[4]
            local dist2 = (mx - minimapX)^2 + (my - minimapY)^2
            if dist2 <= minimapRadius^2 then
                if transformedVertices and #transformedVertices >= 6 then
                    -- Draw polygon shape if available
                    BatchRenderer.queuePolygon(transformedVertices, asteroidColor[1], asteroidColor[2], asteroidColor[3], asteroidColor[4])
                else
                    -- Fallback to circle, use scaled radius
                    BatchRenderer.queueCircle(mx, my, blipRadius or (2 * radiusScale), asteroidColor[1], asteroidColor[2], asteroidColor[3], asteroidColor[4])
                end
            end
        end

        -- Item blips (green)
        local itemColor = {0.2, 0.8, 0.2, 1}
        for _, p in ipairs(cachedBlips.items) do
            local mx, my, blipRadius = p[1], p[2], p[3]
            local dist2 = (mx - minimapX)^2 + (my - minimapY)^2
            if dist2 <= minimapRadius^2 then
                BatchRenderer.queueCircle(mx, my, blipRadius, itemColor[1], itemColor[2], itemColor[3], itemColor[4])
            end
        end

        -- Enemy blips (red)
        local enemyColor = {1, 0.2, 0.2, 1}
        for _, p in ipairs(cachedBlips.enemies) do
            local mx, my, blipRadius = p[1], p[2], p[3]
            local dist2 = (mx - minimapX)^2 + (my - minimapY)^2
            if dist2 <= minimapRadius^2 then
                BatchRenderer.queueCircle(mx, my, blipRadius, enemyColor[1], enemyColor[2], enemyColor[3], enemyColor[4])
            end
        end

        -- Player blip (blue) - render from cache
        if cachedBlips.player then
            local playerColor = {0.2, 0.6, 1, 1}
            local px, py = cachedBlips.player[1], cachedBlips.player[2]
            BatchRenderer.queueCircle(px, py, math.max(4, 3 * radiusScale), playerColor[1], playerColor[2], playerColor[3], playerColor[4]) -- Ensure minimum size
        end
    end
end

-- Returns true if the given screen coordinates are over the minimap circle
function Minimap.isPointOver(sx, sy)
    if not minimapRadius or minimapRadius <= 0 then return false end
    local uiX, uiY = Scaling.toUI(sx, sy) -- This can return nil if outside canvas
    if not uiX or not uiY then return false end -- Prevent error on nil coordinates
    local dx = uiX - minimapX
    local dy = uiY - minimapY
    return dx * dx + dy * dy <= minimapRadius * minimapRadius
end

return Minimap
