-- Minimap System
-- Draws a circular minimap with player, asteroids, and items

local ECS = require('src.ecs')
local Minimap = {}

-- Config
local minimapRadius = 80
local minimapMargin = 20
local minimapWorldRadius = 2000  -- World radius shown on minimap (tune as needed)
local minimapWorldScale = 0.25   -- Visual scale of the world on the minimap (1.0 = actual size)
local minimapX, minimapY

function Minimap.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    minimapX = screenW - minimapRadius - minimapMargin
    minimapY = minimapRadius + minimapMargin

    -- Draw minimap background (circle)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle('fill', minimapX, minimapY, minimapRadius)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle('line', minimapX, minimapY, minimapRadius)

    -- Get player or controlled drone position (center of minimap)
    local controllers = ECS.getEntitiesWith({'Player', 'InputControlled'})
    local playerX, playerY = 0, 0
    if #controllers > 0 then
        local pilotId = controllers[1]
        local input = ECS.getComponent(pilotId, 'InputControlled')
        local targetId = input and input.targetEntity or nil
        local pos
        if targetId then
            pos = ECS.getComponent(targetId, 'Position')
        end
        if not pos then
            pos = ECS.getComponent(pilotId, 'Position')
        end
        if pos then playerX, playerY = pos.x, pos.y end
    end

    -- Helper: world to minimap (player-centered)
    -- Debug toggle
    local debugMinimap = false

    -- Compute combined scale (world units -> minimap pixels)
    local combinedScale = (minimapRadius / minimapWorldRadius) * minimapWorldScale

    local function worldToMinimap(wx, wy)
        -- Offset from player in world coords
        local dx, dy = wx - playerX, wy - playerY
        local scale = minimapRadius / minimapWorldRadius
        return minimapX + dx * scale, minimapY + dy * scale
    end

    -- Draw world boundary (if available)
    local boundaryEntities = ECS.getEntitiesWith({'Boundary'})
    if #boundaryEntities > 0 then
        local b = ECS.getComponent(boundaryEntities[1], 'Boundary')
        if b then
            -- Convert actual world bounds to minimap coordinates (scaled visually by minimapWorldScale)
            local minMX, minMY = worldToMinimap(b.minX, b.minY)
            local maxMX, maxMY = worldToMinimap(b.maxX, b.maxY)
            
            -- Draw the four edges of the boundary, clipping to the minimap circle
            love.graphics.setColor(1, 0.2, 0.2, 0.9)
            local function drawBoundaryEdge(x1, y1, x2, y2)
                -- Only draw if at least one endpoint is within the minimap circle
                local d1 = (x1 - minimapX)^2 + (y1 - minimapY)^2
                local d2 = (x2 - minimapX)^2 + (y2 - minimapY)^2
                if d1 <= minimapRadius * minimapRadius or d2 <= minimapRadius * minimapRadius then
                    love.graphics.line(x1, y1, x2, y2)
                end
            end
            
            -- Draw the four edges of the boundary rectangle
            drawBoundaryEdge(minMX, minMY, maxMX, minMY)  -- Top edge
            drawBoundaryEdge(maxMX, minMY, maxMX, maxMY)  -- Right edge
            drawBoundaryEdge(maxMX, maxMY, minMX, maxMY)  -- Bottom edge
            drawBoundaryEdge(minMX, maxMY, minMX, minMY)  -- Left edge
            
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- Draw asteroids with actual size
    local asteroids = ECS.getEntitiesWith({'Asteroid', 'Position'})
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local asteroidCount = 0
    for _, id in ipairs(asteroids) do
        local pos = ECS.getComponent(id, 'Position')
        local coll = ECS.getComponent(id, 'Collidable')
        local renderable = ECS.getComponent(id, 'Renderable')
        local radius = (coll and coll.radius) or (renderable and renderable.radius) or 12
        if pos then
            asteroidCount = asteroidCount + 1
            local mx, my = worldToMinimap(pos.x, pos.y)
            if debugMinimap and asteroidCount <= 2 then
                print(string.format("[Minimap] Asteroid %d: world (%.1f, %.1f) -> minimap (%.1f, %.1f), player at (%.1f, %.1f)", 
                    asteroidCount, pos.x, pos.y, mx, my, playerX, playerY))
            end
            local blipRadius = math.max(2, radius * combinedScale)
            if ((mx - minimapX)^2 + (my - minimapY)^2) <= (minimapRadius-blipRadius)^2 then
                love.graphics.circle('fill', mx, my, blipRadius)
            end
        end
    end

    -- Draw items with actual size
    local items = ECS.getEntitiesWith({'Item', 'Position'})
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    for _, id in ipairs(items) do
        local pos = ECS.getComponent(id, 'Position')
        local coll = ECS.getComponent(id, 'Collidable')
        local renderable = ECS.getComponent(id, 'Renderable')
        local radius = (coll and coll.radius) or (renderable and renderable.radius) or 6
        if pos then
            local mx, my = worldToMinimap(pos.x, pos.y)
            local blipRadius = math.max(1.5, radius * combinedScale)
            if ((mx - minimapX)^2 + (my - minimapY)^2) <= (minimapRadius-blipRadius)^2 then
                love.graphics.circle('fill', mx, my, blipRadius)
            end
        end
    end

    -- Draw player with actual size
    local trackedEntityId = nil
    if #controllers > 0 then
        local pilotId = controllers[1]
        local input = ECS.getComponent(pilotId, 'InputControlled')
        if input and input.targetEntity then
            trackedEntityId = input.targetEntity
        else
            trackedEntityId = pilotId
        end
    end
    local playerColl, playerRenderable, playerRadius
    if trackedEntityId then
        playerColl = ECS.getComponent(trackedEntityId, 'Collidable')
        playerRenderable = ECS.getComponent(trackedEntityId, 'Renderable')
        playerRadius = (playerColl and playerColl.radius) or (playerRenderable and playerRenderable.radius) or 8
    else
        playerRadius = 8
    end
    love.graphics.setColor(0.2, 0.6, 1, 1)
    local playerBlipRadius = math.max(3, playerRadius * combinedScale)
    love.graphics.circle('fill', minimapX, minimapY, playerBlipRadius)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns true if the given screen coordinates are over the minimap circle
function Minimap.isPointOver(sx, sy)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local mx = screenW - minimapRadius - minimapMargin
    local my = minimapRadius + minimapMargin
    return (sx - mx) * (sx - mx) + (sy - my) * (sy - my) <= minimapRadius * minimapRadius
end

return Minimap
