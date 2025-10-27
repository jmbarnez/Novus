---@diagnostic disable: undefined-global
-- HUD Minimap Module
-- Draws a circular minimap with player, asteroids, and items

local ECS = require('src.ecs')
local BatchRenderer = require('src.ui.batch_renderer')
local Scaling = require('src.scaling')
local Constants = require('src.constants')
local EntityHelpers = require('src.entity_helpers')

local HUDMinimap = {}

local BASE_MINIMAP_RADIUS = 80
local BASE_MINIMAP_MARGIN = 20
local MINIMAP_WORLD_RADIUS = 800

local minimapX, minimapY = 0, 0
local minimapRadius = BASE_MINIMAP_RADIUS

local function computeLayout()
    local scaleX = Scaling.canvasScaleX or 1
    local scaleY = Scaling.canvasScaleY or 1
    local scaleU = math.min(scaleX, scaleY)

    local marginX = BASE_MINIMAP_MARGIN * scaleX
    local marginY = BASE_MINIMAP_MARGIN * scaleY
    local baseRadius = BASE_MINIMAP_RADIUS * scaleU
    minimapRadius = math.max(48, baseRadius)

    local screenRight = Scaling.getCurrentWidth()
    minimapX = screenRight - marginX - minimapRadius
    minimapY = marginY + minimapRadius

    return minimapX, minimapY, minimapRadius
end

local function projectToMinimap(worldX, worldY, playerX, playerY, scale)
    local dx, dy = worldX - playerX, worldY - playerY
    if dx * dx + dy * dy > MINIMAP_WORLD_RADIUS * MINIMAP_WORLD_RADIUS then
        return nil, nil
    end

    return minimapX + dx * scale, minimapY + dy * scale
end

function HUDMinimap.draw()
    computeLayout()

    -- Draw minimap background
    BatchRenderer.queueCircle(minimapX, minimapY, minimapRadius, 0, 0, 0, 0.75)
    BatchRenderer.queueCircleLine(minimapX, minimapY, minimapRadius, 1, 1, 1, 0.8)

    local playerX, playerY = EntityHelpers.getPlayerPosition()
    local scale = minimapRadius / MINIMAP_WORLD_RADIUS

    -- Player marker
    BatchRenderer.queueCircle(minimapX, minimapY, math.max(4, 3 * scale), 0.2, 0.6, 1, 1)

    -- Asteroids
    local asteroidColor = {0.7, 0.7, 0.7, 1}
    for _, id in ipairs(ECS.getEntitiesWith({ 'Asteroid', 'Position' })) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local mx, my = projectToMinimap(pos.x, pos.y, playerX, playerY, scale)
            if mx and my then
                BatchRenderer.queueCircle(mx, my, math.max(2, 2 * scale), asteroidColor[1], asteroidColor[2], asteroidColor[3], asteroidColor[4])
            end
        end
    end

    -- Items
    local itemColor = {0.2, 0.8, 0.2, 1}
    for _, id in ipairs(ECS.getEntitiesWith({ 'Item', 'Position' })) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local mx, my = projectToMinimap(pos.x, pos.y, playerX, playerY, scale)
            if mx and my then
                BatchRenderer.queueCircle(mx, my, math.max(2, 1.5 * scale), itemColor[1], itemColor[2], itemColor[3], itemColor[4])
            end
        end
    end

    -- Enemies
    local enemyColor = {1, 0.2, 0.2, 1}
    for _, id in ipairs(EntityHelpers.getEnemyShips()) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local mx, my = projectToMinimap(pos.x, pos.y, playerX, playerY, scale)
            if mx and my then
                BatchRenderer.queueCircle(mx, my, math.max(3, 2 * scale), enemyColor[1], enemyColor[2], enemyColor[3], enemyColor[4])
            end
        end
    end

    -- World boundary ring (clamped to minimap radius)
    local boundaryRadius = math.min(minimapRadius - 2, Constants.WORLD_RADIUS * scale)
    if boundaryRadius > 0 then
        BatchRenderer.queueCircleLine(minimapX, minimapY, boundaryRadius, 1, 1, 1, 0.25)
    end
end

function HUDMinimap.isPointOver(sx, sy)
    if not minimapRadius or minimapRadius <= 0 then return false end
    local uiX, uiY = Scaling.toUI(sx, sy)
    if not uiX or not uiY then return false end
    local dx = uiX - minimapX
    local dy = uiY - minimapY
    return dx * dx + dy * dy <= minimapRadius * minimapRadius
end

function HUDMinimap.getLayout()
    return computeLayout()
end

return HUDMinimap
