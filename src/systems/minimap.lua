---@diagnostic disable: undefined-global
-- Minimap System
-- Draws a circular minimap with player, asteroids, and items

local ECS = require('src.ecs')
local Minimap = {}
local minimapWorldRadius = 2000  -- World radius shown on minimap (tune as needed)

-- Throttle/caching config
local UPDATE_INTERVAL_FRAMES = 3
local lastUpdateFrame = -1
local cachedBlips = nil
local lastPlayerX, lastPlayerY = nil, nil
local lastPlayerSpeed = 0

local function getFrameCount()
    -- Uses love.timer.getTime (30 fps granularity is fine for HUD)
    return math.floor(love.timer.getTime() * 60)
end

Minimap._internal = {
    UPDATE_INTERVAL_FRAMES = UPDATE_INTERVAL_FRAMES
}

function Minimap._shouldUpdateCache(playerX, playerY, playerSpeed)
    local frame = getFrameCount()
    if lastUpdateFrame < 0 or frame - lastUpdateFrame >= UPDATE_INTERVAL_FRAMES then
        -- Throttle: only update every N frames, unless player is moving fast
        if playerSpeed > 500 then  -- Arbitrary: treat as 'fast'
            return true
        end
        return true
    end
    -- If player moved a lot between intervals, force update
    if lastPlayerX and lastPlayerY then
        if math.abs(playerX - lastPlayerX) > 100 or math.abs(playerY - lastPlayerY) > 100 then
            return true
        end
    end
    return false
end

function Minimap._buildBlipCache(minimapX, minimapY, minimapRadius, playerX, playerY, combinedScale)
    local minR2 = (minimapRadius - 20) ^ 2 -- margin for blips on edge
    local maxR2 = minimapRadius ^ 2
    local blips = {asteroids = {}, items = {}, enemies = {}, player = nil, boundary = nil}

    -- Asteroids
    for _, id in ipairs(ECS.getEntitiesWith({ 'Asteroid', 'Position' })) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local dx, dy = pos.x - playerX, pos.y - playerY
            local r2 = dx * dx + dy * dy
            if r2 < minimapWorldRadius * minimapWorldRadius then -- let's early discard outlier objects
                local scale = minimapRadius / minimapWorldRadius
                local mx, my = minimapX + dx * scale, minimapY + dy * scale
                local blipRadius = 2
                if ((mx - minimapX) ^ 2 + (my - minimapY) ^ 2) <= (minimapRadius - blipRadius) ^ 2 then
                    table.insert(blips.asteroids, {mx, my})
                end
            end
        end
    end

    -- Items
    for _, id in ipairs(ECS.getEntitiesWith({ 'Item', 'Position' })) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local dx, dy = pos.x - playerX, pos.y - playerY
            if dx * dx + dy * dy < minimapWorldRadius * minimapWorldRadius then
                local scale = minimapRadius / minimapWorldRadius
                local mx, my = minimapX + dx * scale, minimapY + dy * scale
                local blipRadius = 1.5
                if ((mx - minimapX) ^ 2 + (my - minimapY) ^ 2) <= (minimapRadius - blipRadius) ^ 2 then
                    table.insert(blips.items, {mx, my})
                end
            end
        end
    end

    -- Enemies
    for _, id in ipairs(ECS.getEntitiesWith({'Hull', 'Position'})) do
        local pos = ECS.getComponent(id, 'Position')
        local controlledBy = ECS.getComponent(id, 'ControlledBy')
        if pos and not (controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, 'Player')) then
            local dx, dy = pos.x - playerX, pos.y - playerY
            if dx * dx + dy * dy < minimapWorldRadius * minimapWorldRadius then
                local scale = minimapRadius / minimapWorldRadius
                local mx, my = minimapX + dx * scale, minimapY + dy * scale
                local blipRadius = 2
                if ((mx - minimapX) ^ 2 + (my - minimapY) ^ 2) <= (minimapRadius - blipRadius) ^ 2 then
                    table.insert(blips.enemies, {mx, my})
                end
            end
        end
    end

    blips.player = {minimapX, minimapY}
    -- You can similarly cache boundaries or other objects if desired.
    return blips
end

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
    love.graphics.setColor(0, 0, 0, 1.0)
    love.graphics.circle('fill', minimapX, minimapY, minimapRadius)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle('line', minimapX, minimapY, minimapRadius)

    -- Get player (center)
    local controllers = ECS.getEntitiesWith({'Player', 'InputControlled'})
    local playerX, playerY = 0, 0
    local playerSpeed = 0
    if #controllers > 0 then
        local pilotId = controllers[1]
        local input = ECS.getComponent(pilotId, 'InputControlled')
        local targetId = input and input.targetEntity or nil
        local pos
        if targetId then
            pos = ECS.getComponent(targetId, 'Position')
            local vel = ECS.getComponent(targetId, 'Velocity')
            if vel then
                playerSpeed = math.sqrt(vel.vx*vel.vx + vel.vy*vel.vy)
            end
        end
        if not pos then
            pos = ECS.getComponent(pilotId, 'Position')
        end
        if pos then playerX, playerY = pos.x, pos.y end
    end
    local combinedScale = (minimapRadius / minimapWorldRadius) * minimapWorldScale
    -- Throttle & cache:
    local frame = getFrameCount()
    if Minimap._shouldUpdateCache(playerX, playerY, playerSpeed) then
        cachedBlips = Minimap._buildBlipCache(minimapX, minimapY, minimapRadius, playerX, playerY, combinedScale)
        lastUpdateFrame = frame
        lastPlayerX, lastPlayerY = playerX, playerY
        lastPlayerSpeed = playerSpeed
    end
    -- Render from cache:
    if cachedBlips then
        love.graphics.setColor(0.7, 0.7, 0.7, 1) -- asteroid color
        for _, p in ipairs(cachedBlips.asteroids) do
            love.graphics.circle('fill', p[1], p[2], 2)
        end
        love.graphics.setColor(0.2, 0.8, 0.2, 1) -- item color
        for _, p in ipairs(cachedBlips.items) do
            love.graphics.circle('fill', p[1], p[2], 1.5)
        end
        love.graphics.setColor(1, 0.2, 0.2, 1) -- enemy color
        for _, p in ipairs(cachedBlips.enemies) do
            love.graphics.circle('fill', p[1], p[2], 2)
        end
        -- Player blip
        love.graphics.setColor(0.2, 0.6, 1, 1)
        love.graphics.circle('fill', minimapX, minimapY, 3)
        love.graphics.setColor(1,1,1,1)
    end
end

-- Returns true if the given screen coordinates are over the minimap circle
function Minimap.isPointOver(sx, sy)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local mx = screenW - minimapRadius - minimapMargin
    local my = minimapRadius + minimapMargin
    return (sx - mx) * (sx - mx) + (sy - my) * (sy - my) <= minimapRadius * minimapRadius
end

return Minimap
