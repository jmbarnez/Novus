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

-- Override setOpen so map becomes full-screen when opened
function MapWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if state then
        -- Fill the current screen/canvas
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        self.width = w
        self.height = h
        self.position = {x = 0, y = 0}
        -- Initialize pan/zoom
        self.zoom = self.zoom or 1.0
        self.isPanning = false
    end
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

    -- Map rectangle (fit within window content area, respect top/bottom bars)
    local padding = Theme.spacing.padding
    local mapX = x + padding
    local mapY = y + Theme.window.topBarHeight + padding
    local mapW = w - padding * 2
    local mapH = h - Theme.window.topBarHeight - Theme.window.bottomBarHeight - padding * 2
    local centerX = mapX + mapW / 2
    local centerY = mapY + mapH / 2

    -- World bounds
    local boundaryEntities = ECS.getEntitiesWith({'Boundary'})
    local minX, minY, maxX, maxY
    if #boundaryEntities > 0 then
        local b = ECS.getComponent(boundaryEntities[1], 'Boundary')
        if b and b.minX and b.minY and b.maxX and b.maxY then
            minX, minY, maxX, maxY = b.minX, b.minY, b.maxX, b.maxY
        else
            minX, minY, maxX, maxY = Constants.world_min_x, Constants.world_min_y, Constants.world_max_x, Constants.world_max_y
        end
    else
        minX, minY, maxX, maxY = Constants.world_min_x, Constants.world_min_y, Constants.world_max_x, Constants.world_max_y
    end

    local worldWidth = maxX - minX
    local worldHeight = maxY - minY
    -- Scale to fit world into the map rect
    local scaleX = mapW / worldWidth
    local scaleY = mapH / worldHeight
    local baseScale = math.min(scaleX, scaleY) * 0.95 -- small padding
    self.zoom = self.zoom or 1.0
    local scale = baseScale * self.zoom

    -- Store values for input handlers
    self._mapX, self._mapY, self._mapW, self._mapH = mapX, mapY, mapW, mapH
    self._baseScale = baseScale
    self._scale = scale

    -- Map world center
    local worldCenterX = (minX + maxX) / 2
    local worldCenterY = (minY + maxY) / 2

    -- Use pan center if present, else world center
    self.panX = self.panX or worldCenterX
    self.panY = self.panY or worldCenterY
    local function worldToMap(wx, wy)
        return centerX + (wx - self.panX) * scale, centerY + (wy - self.panY) * scale
    end

    -- Background rectangle (map area) - use black background
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle('fill', mapX, mapY, mapW, mapH)
    love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', mapX, mapY, mapW, mapH)
    love.graphics.setLineWidth(1)

    -- Draw boundary rectangle (clipped into map area)
    love.graphics.setColor(1, 0.2, 0.2, 0.9 * alpha)
    local bx1, by1 = worldToMap(minX, minY)
    local bx2, by2 = worldToMap(maxX, maxY)
    love.graphics.rectangle('line', bx1, by1, bx2 - bx1, by2 - by1)

    -- Store world bounds for input handlers
    self._minX, self._minY, self._maxX, self._maxY = minX, minY, maxX, maxY

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
            -- Only draw if inside map rectangle
            if mx >= mapX and mx <= mapX + mapW and my >= mapY and my <= mapY + mapH then
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
            if mx >= mapX and mx <= mapX + mapW and my >= mapY and my <= mapY + mapH then
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
            if mx >= mapX and mx <= mapX + mapW and my >= mapY and my <= mapY + mapH then
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
            if mx >= mapX and mx <= mapX + mapW and my >= mapY and my <= mapY + mapH then
                love.graphics.circle('fill', mx, my, 4)
            end
        end
    end

    -- Draw close/reset controls
    self:drawCloseButton(x, y, alpha)
    -- Reset button
    local btnW, btnH = 70, 20
    local btnX = x + 8
    local btnY = y + 6
    love.graphics.setColor(Theme.colors.bgLight[1], Theme.colors.bgLight[2], Theme.colors.bgLight[3], alpha)
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 4, 4)
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.rectangle('line', btnX, btnY, btnW, btnH, 4, 4)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.printf('Reset View', btnX, btnY + 3, btnW, 'center')
    self.resetButtonRect = {x = btnX, y = btnY, w = btnW, h = btnH}

    -- Title text
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.printf("Map", x + 8, y + 4, w - 16, 'left')
end

-- Input handling for panning
function MapWindow:mousepressed(mx, my, button)
    if not self.isOpen then return end
    local mapX, mapY, mapW, mapH = self._mapX or (self.position.x + Theme.spacing.padding), self._mapY or (self.position.y + Theme.window.topBarHeight + Theme.spacing.padding), self._mapW or self.width - Theme.spacing.padding*2, self._mapH or self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - Theme.spacing.padding*2
    if self.resetButtonRect and mx >= self.resetButtonRect.x and mx <= self.resetButtonRect.x + self.resetButtonRect.w
       and my >= self.resetButtonRect.y and my <= self.resetButtonRect.y + self.resetButtonRect.h then
        -- Reset view
        self:resetView()
        return
    end

    if mx >= mapX and mx <= mapX + mapW and my >= mapY and my <= mapY + mapH then
        if button == 1 then
            self.isPanning = true
            self._lastMouseX = mx
            self._lastMouseY = my
        end
        return
    end
    -- Default behavior: let base window handle top-bar drag if clicked there
    WindowBase.mousepressed(self, mx, my, button)
end

function MapWindow:mousereleased(mx, my, button)
    if not self.isOpen then return end
    if button == 1 then self.isPanning = false end
    -- Ensure base window release logic runs (stop window dragging)
    WindowBase.mousereleased(self, mx, my, button)
end

function MapWindow:mousemoved(mx, my, dx, dy)
    if not self.isOpen then return end
    if self.isPanning then
        -- Use stored scale for conversion from UI delta to world delta
        local scale = self._scale or (self._baseScale or 1) * (self.zoom or 1)
        if scale == 0 then return end
        -- Pan in world coordinates
        self.panX = self.panX - dx / scale
        self.panY = self.panY - dy / scale
    else
        WindowBase.mousemoved(self, mx, my, dx, dy)
    end
end

function MapWindow:resetView()
    if not self._minX or not self._maxX then
        local boundaryEntities = ECS.getEntitiesWith({'Boundary'})
        if #boundaryEntities > 0 then
            local b = ECS.getComponent(boundaryEntities[1], 'Boundary')
            if b then
                self._minX, self._minY, self._maxX, self._maxY = b.minX, b.minY, b.maxX, b.maxY
            end
        end
    end
    self.panX = (self._minX + self._maxX) / 2
    self.panY = (self._minY + self._maxY) / 2
    self.zoom = 1.0
end

-- Zoom with mouse wheel; anchor zoom at mouse cursor
function MapWindow:wheelmoved(dx, dy)
    if not self.isOpen then return end
    if dy == 0 then return end
    local mapX, mapY, mapW, mapH = self._mapX or self.position.x + Theme.spacing.padding, self._mapY or self.position.y + Theme.window.topBarHeight + Theme.spacing.padding, self._mapW or self.width - Theme.spacing.padding*2, self._mapH or self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - Theme.spacing.padding*2
    local baseScale = self._baseScale or 1
    local oldZoom = self.zoom or 1
    local newZoom = oldZoom * (1 + 0.15 * (dy > 0 and 1 or -1))
    newZoom = math.max(0.1, math.min(newZoom, 10))
    local mx, my = love.mouse.getPosition()
    -- Map UI coords are already in screen coords; we need to ensure the mouse is over the map
    if mx < mapX or mx > mapX + mapW or my < mapY or my > mapY + mapH then
        self.zoom = newZoom
        return
    end
    local centerX = mapX + mapW / 2
    local centerY = mapY + mapH / 2
    local oldScale = baseScale * oldZoom
    local newScale = baseScale * newZoom
    self.panX = self.panX or ((self._minX + self._maxX) / 2)
    self.panY = self.panY or ((self._minY + self._maxY) / 2)
    -- World coords under mouse before/after
    local worldBeforeX = self.panX + (mx - centerX) / oldScale
    local worldBeforeY = self.panY + (my - centerY) / oldScale
    local worldAfterX = self.panX + (mx - centerX) / newScale
    local worldAfterY = self.panY + (my - centerY) / newScale
    -- Adjust pan so the world point stays under the mouse
    self.panX = self.panX + (worldBeforeX - worldAfterX)
    self.panY = self.panY + (worldBeforeY - worldAfterY)
    self.zoom = newZoom
end

return MapWindow
