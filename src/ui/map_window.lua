---@diagnostic disable: undefined-global
-- Map Window - Windowed full-map display
-- Uses world boundary to render an overview map with entities

local ECS = require('src.ecs')
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Constants = require('src.constants')

local MapWindow = WindowBase:new{
    width = 620,
    height = 420,
    isOpen = false,
    animAlphaSpeed = 2.0,
    elasticitySpring = 12,
    elasticityDamping = 0.7,
}

function MapWindow:toggle()
    self:setOpen(not self.isOpen)
end

function MapWindow:getOpen()
    return self.isOpen
end

-- Draw a scaled map that fits the world bounds
function MapWindow:draw(viewportWidth, viewportHeight)
    WindowBase.draw(self)
    if not self.isOpen or not self.position then return end
    local x, y = self.position.x, self.position.y
    local w, h = self.width, self.height
    local alpha = self.animAlpha

    -- Map radius and center in window coordinates
    local mapRadius = math.min(w, h) * 0.4
    local centerX = x + w / 2
    local centerY = y + h / 2

    -- World bounds
    local boundaryEntities = ECS.getEntitiesWith({'Boundary'})
    local minX, minY, maxX, maxY
    if #boundaryEntities > 0 then
        local b = ECS.getComponent(boundaryEntities[1], 'Boundary')
        minX, minY, maxX, maxY = b.minX or -2000, b.minY or -2000, b.maxX or 2000, b.maxY or 2000
    else
        minX, minY, maxX, maxY = -2000, -2000, 2000, 2000
    end

    local worldWidth = maxX - minX
    local worldHeight = maxY - minY
    local scaleX = (mapRadius * 2) / worldWidth
    local scaleY = (mapRadius * 2) / worldHeight
    local scale = math.min(scaleX, scaleY) * 0.95 -- padding

    -- Map world center
    local worldCenterX = (minX + maxX) / 2
    local worldCenterY = (minY + maxY) / 2

    local function worldToMap(wx, wy)
        return centerX + (wx - worldCenterX) * scale, centerY + (wy - worldCenterY) * scale
    end

    -- Background circle
    love.graphics.setColor(0, 0, 0, 0.8 * alpha)
    love.graphics.circle('fill', centerX, centerY, mapRadius)
    love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', centerX, centerY, mapRadius)
    love.graphics.setLineWidth(1)

    -- Draw boundary rectangle (clipped into map area)
    love.graphics.setColor(1, 0.2, 0.2, 0.9 * alpha)
    local bx1, by1 = worldToMap(minX, minY)
    local bx2, by2 = worldToMap(maxX, maxY)
    love.graphics.rectangle('line', bx1, by1, bx2 - bx1, by2 - by1)

    -- Draw asteroids
    local asteroids = ECS.getEntitiesWith({'Asteroid', 'Position'})
    love.graphics.setColor(0.7, 0.7, 0.7, 1 * alpha)
    for _, id in ipairs(asteroids) do
        local pos = ECS.getComponent(id, 'Position')
        local coll = ECS.getComponent(id, 'Collidable')
        if pos then
            local mx, my = worldToMap(pos.x, pos.y)
            local radius = (coll and coll.radius) or 8
            local blip = math.max(1.5, radius * scale)
            -- Only draw if inside map radius
            if (mx - centerX)^2 + (my - centerY)^2 <= (mapRadius - blip)^2 then
                love.graphics.circle('fill', mx, my, blip)
            end
        end
    end

    -- Draw items
    local items = ECS.getEntitiesWith({'Item', 'Position'})
    love.graphics.setColor(0.2, 0.8, 0.2, 1 * alpha)
    for _, id in ipairs(items) do
        local pos = ECS.getComponent(id, 'Position')
        if pos then
            local mx, my = worldToMap(pos.x, pos.y)
            if (mx - centerX)^2 + (my - centerY)^2 <= (mapRadius - 2)^2 then
                love.graphics.circle('fill', mx, my, 2)
            end
        end
    end

    -- Draw enemies
    local enemies = ECS.getEntitiesWith({'Hull', 'Position'})
    love.graphics.setColor(1, 0.2, 0.2, 1 * alpha)
    for _, id in ipairs(enemies) do
        local pos = ECS.getComponent(id, 'Position')
        local controlledBy = ECS.getComponent(id, 'ControlledBy')
        -- Skip player's ship
        if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, 'Player') then
            goto skip_enemy
        end
        if pos then
            local mx, my = worldToMap(pos.x, pos.y)
            if (mx - centerX)^2 + (my - centerY)^2 <= (mapRadius - 3)^2 then
                love.graphics.circle('fill', mx, my, 3)
            end
        end
        ::skip_enemy::
    end

    -- Draw player position
    local controllers = ECS.getEntitiesWith({'Player', 'InputControlled'})
    if #controllers > 0 then
        local pilotId = controllers[1]
        local input = ECS.getComponent(pilotId, 'InputControlled')
        local tracked = input and input.targetEntity or pilotId
        local pos = ECS.getComponent(tracked, 'Position')
        if pos then
            local mx, my = worldToMap(pos.x, pos.y)
            love.graphics.setColor(0.2, 0.6, 1, 1 * alpha)
            love.graphics.circle('fill', mx, my, 4)
        end
    end

    -- Title text
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Map", x + 8, y + 8, w - 16, 'left')
end

return MapWindow
