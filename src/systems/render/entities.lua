-- Render Entities Module - Handles basic entity rendering (polygons, circles, rectangles)

local ECS = require('src.ecs')
local PlasmaTheme = require('src.ui.plasma_theme')
local Theme = require('src.ui.theme')
local RenderEffects = require('src.systems.render.effects')

-- Resolve layered colors from a design-like table or fallback to simple color array
local function resolveColors(colorSpec)
    local layers = {
        stripes = {1,1,1,1},
        cockpit = {0.8, 0.8, 0.8, 1}
    }
    if not colorSpec then return layers end
    
    if colorSpec[1] and type(colorSpec[1]) == 'number' then
        local c = {colorSpec[1] or 1, colorSpec[2] or 1, colorSpec[3] or 1, colorSpec[4] or 1}
        layers.stripes = c
        layers.cockpit = {c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, c[4]}
        return layers
    end

    if colorSpec.stripes and type(colorSpec.stripes) == 'table' and colorSpec.stripes[1] and type(colorSpec.stripes[1]) == 'number' then
        layers.stripes = colorSpec.stripes
    end
    if colorSpec.cockpit and type(colorSpec.cockpit) == 'table' and colorSpec.cockpit[1] and type(colorSpec.cockpit[1]) == 'number' then
        layers.cockpit = colorSpec.cockpit
    end
    
    if colorSpec.colors and type(colorSpec.colors) == 'table' then
        if colorSpec.colors.base and type(colorSpec.colors.base) == 'table' then
            local c = colorSpec.colors.base
            if c[1] and type(c[1]) == 'number' then
                local ctab = {c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1}
                layers.stripes = ctab
                layers.cockpit = colorSpec.colors.cockpit or {ctab[1] * 0.8, ctab[2] * 0.8, ctab[3] * 0.8, ctab[4]}
            end
        end
    end
    return layers
end

-- Helper function to check if an entity is on-screen (with padding for safety)
local function isOnScreen(x, y, radius, cameraPos, camera)
    if not (cameraPos and camera) then return true end

    local padding = 200
    local viewportWidth = camera.width / camera.zoom
    local viewportHeight = camera.height / camera.zoom

    local left = cameraPos.x - padding
    local right = cameraPos.x + viewportWidth + padding
    local top = cameraPos.y - padding
    local bottom = cameraPos.y + viewportHeight + padding

    return x + radius >= left and x - radius <= right and
           y + radius >= top and y - radius <= bottom
end

-- Helper function to draw a polygon shape
local function drawPolygon(x, y, polygonShape, color, texture)
    local vertices = polygonShape.vertices
    -- local rotation = polygonShape.rotation  -- NO per-vertex rotation here!
    if not polygonShape or not color then return end

    local colors = resolveColors(color)
    if not vertices or #vertices < 3 then return end

    local worldVertices = {}
    for i = 1, #vertices do
        local v = vertices[i]
        -- Just add x and y, NO rotation (handle in parent love.graphics.rotate context)
        table.insert(worldVertices, x + v.x)
        table.insert(worldVertices, y + v.y)
    end

    -- Draw main hull (stripes)
    love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], colors.stripes[4])
    love.graphics.polygon("fill", worldVertices)

    -- Draw texture shapes
    if texture then
        for field, shapes in pairs(texture) do
            if type(shapes) == "table" then
                for _, shape in ipairs(shapes) do
                    if shape.x and shape.y and shape.r and shape.color then
                        love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], shape.color[4])
                        love.graphics.circle("fill", x + shape.x, y + shape.y, shape.r)
                    elseif shape.x1 and shape.y1 and shape.x2 and shape.y2 and shape.color then
                        love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], shape.color[4])
                        love.graphics.setLineWidth(shape.lineWidth or 3)
                        love.graphics.line(x + shape.x1, y + shape.y1, x + shape.x2, y + shape.y2)
                    end
                end
            end
        end
    end

    -- Draw plasma-style outline
    love.graphics.setColor(0, 0, 0, colors.stripes[4])
    love.graphics.setLineWidth(4)
    love.graphics.polygon("line", worldVertices)

    love.graphics.setColor(colors.stripes[1] * 0.3, colors.stripes[2] * 0.3, colors.stripes[3] * 0.3, colors.stripes[4])
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", worldVertices)

    love.graphics.setLineWidth(1)
end

local RenderEntities = {}

function RenderEntities.drawItems(cullingCameraPos, cullingCamera)
    local renderableEntities = ECS.getEntitiesWith({"Position", "Renderable"})
    local culledItems = 0
    local renderedItems = 0
    
    for _, entityId in ipairs(renderableEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local renderable = ECS.getComponent(entityId, "Renderable")
        if not position or not renderable then goto continue_entity end
        
        local item = ECS.getComponent(entityId, "Item")
        local stack = ECS.getComponent(entityId, "Stack")
        if renderable.shape == "item" and item and item.def and item.def.draw then
            if not isOnScreen(position.x, position.y, 50, cullingCameraPos, cullingCamera) then
                culledItems = culledItems + 1
                goto continue_entity
            end
            renderedItems = renderedItems + 1
            love.graphics.push()
            love.graphics.translate(position.x, position.y)
            love.graphics.scale(0.4, 0.4)
            item.def:draw(0, 0)
            love.graphics.pop()
        else
            if renderable.shape == "rectangle" and renderable.width and renderable.height then
                if renderable.color then
                    local cols = resolveColors(renderable.color)
                    love.graphics.setColor(cols.stripes[1], cols.stripes[2], cols.stripes[3], cols.stripes[4])
                end
                love.graphics.rectangle("fill",
                    position.x - renderable.width/2,
                    position.y - renderable.height/2,
                    renderable.width,
                    renderable.height)
                
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line",
                    position.x - renderable.width/2,
                    position.y - renderable.height/2,
                    renderable.width,
                    renderable.height)
                love.graphics.setLineWidth(1)
            elseif renderable.shape == "circle" and renderable.radius then
                if ECS.hasComponent(entityId, "CrystalFormation") then
                    local cf = ECS.getComponent(entityId, "CrystalFormation")
                    if not cf then goto continue_entity end
                    if not isOnScreen(position.x, position.y, cf.size * 2, cullingCameraPos, cullingCamera) then
                        goto continue_entity
                    end
                    love.graphics.push()
                    love.graphics.translate(position.x, position.y)
                    for i = 1, cf.shardCount do
                        local angle = (i / cf.shardCount) * (2 * math.pi) + (i % 2 == 0 and 0.2 or -0.2)
                        local len = cf.size * (0.6 + math.random() * 0.6)
                        local w = cf.size * 0.35
                        local x1, y1 = 0, 0
                        local x2 = math.cos(angle) * len
                        local y2 = math.sin(angle) * len
                        local bx = math.cos(angle + math.pi/2) * w
                        local by = math.sin(angle + math.pi/2) * w
                        local px1 = x2 + bx
                        local py1 = y2 + by
                        local px2 = x2 - bx
                        local py2 = y2 - by
                        love.graphics.setColor(cf.color[1], cf.color[2], cf.color[3], cf.color[4] or 1)
                        love.graphics.polygon("fill", x1, y1, px1, py1, px2, py2)
                        love.graphics.setColor(1, 1, 1, 0.6)
                        love.graphics.polygon("fill", 0, 0, x2 * 0.6, y2 * 0.6, x2 * 0.4, y2 * 0.4)
                    end
                    love.graphics.pop()
                else
                    if renderable.color then
                        local cols = resolveColors(renderable.color)
                        love.graphics.setColor(cols.stripes[1], cols.stripes[2], cols.stripes[3], cols.stripes[4])
                    end
                    love.graphics.circle("fill", position.x, position.y, renderable.radius)
                    
                    love.graphics.setColor(0, 0, 0, 1)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", position.x, position.y, renderable.radius)
                    love.graphics.setLineWidth(1)
                end
                
                local cannonballBorder = ECS.getComponent(entityId, "CannonballBorder")
                if cannonballBorder then
                    love.graphics.setColor(cannonballBorder.borderColor)
                    love.graphics.circle("line", position.x, position.y, renderable.radius)
                end
            elseif renderable.shape == "polygon" then
                local polygonShape = ECS.getComponent(entityId, "PolygonShape")
                if polygonShape then
                    local asteroid = ECS.getComponent(entityId, "Asteroid")
                    local wreckage = ECS.getComponent(entityId, "Wreckage")
                    if (asteroid or wreckage) then
                        local collidable = ECS.getComponent(entityId, "Collidable")
                        local radius = collidable and collidable.radius or 20
                        if not isOnScreen(position.x, position.y, radius, cullingCameraPos, cullingCamera) then
                            goto continue_entity
                        end
                    end

                    local controlledBy = ECS.getComponent(entityId, "ControlledBy")
                    local isPlayerDrone = false
                    if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player") then
                        isPlayerDrone = true
                    end
                    local isShip = ECS.hasComponent(entityId, "Hull")
                    if isPlayerDrone then
                        local playerRotation = polygonShape.rotation or 0
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        love.graphics.rotate(playerRotation)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture)
                        love.graphics.pop()
                    elseif isShip then
                        local enemyRotation = polygonShape.rotation or 0
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        love.graphics.rotate(enemyRotation)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture)
                        love.graphics.pop()
                    else
                        drawPolygon(position.x, position.y, polygonShape, renderable.color, renderable.texture)
                    end
                end
            end
        end
        ::continue_entity::
    end
    
    -- Draw main entities first so effects appear above
    RenderEffects.drawWarpGates()
    
    -- World tooltips are now handled by WorldTooltipsSystem
    return renderedItems, culledItems
end

return RenderEntities

