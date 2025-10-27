-- Render Entities Module - Handles basic entity rendering (polygons, circles, rectangles)

local ECS = require('src.ecs')
local PlasmaTheme = require('src.ui.plasma_theme')
local Theme = require('src.ui.theme')
local RenderEffects = require('src.systems.render.effects')

-- Resolve layered colors from a design-like table or fallback to simple color array
local function resolveColors(colorSpec)
    local layers = {
        stripes = {1,1,1,1},
        cockpit = {0.8, 0.8, 0.8, 1},
        accent = {0.9, 0.9, 0.9, 0.7},   -- For asteroid highlights
        shadow = {0.3, 0.3, 0.3, 0.8},   -- For asteroid shadows
        detail = {0.8, 0.8, 0.8, 0.5}    -- For asteroid surface details
    }
    if not colorSpec then return layers end

    -- Handle multi-layer color format (for asteroids)
    if colorSpec.stripes and type(colorSpec.stripes) == 'table' and colorSpec.stripes[1] and type(colorSpec.stripes[1]) == 'number' then
        layers.stripes = colorSpec.stripes
        layers.accent = colorSpec.accent or {math.min(1, colorSpec.stripes[1] + 0.1), math.min(1, colorSpec.stripes[2] + 0.1), math.min(1, colorSpec.stripes[3] + 0.1), 0.7}
        layers.shadow = colorSpec.shadow or {colorSpec.stripes[1] * 0.6, colorSpec.stripes[2] * 0.6, colorSpec.stripes[3] * 0.6, 0.8}
        layers.detail = colorSpec.detail or {0.8, 0.8, 0.8, 0.5}
        return layers
    end

    if colorSpec[1] and type(colorSpec[1]) == 'number' then
        local c = {colorSpec[1] or 1, colorSpec[2] or 1, colorSpec[3] or 1, colorSpec[4] or 1}
        layers.stripes = c
        layers.cockpit = {c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, c[4]}
        layers.accent = {math.min(1, c[1] + 0.1), math.min(1, c[2] + 0.1), math.min(1, c[3] + 0.1), 0.7}
        layers.shadow = {c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 0.8}
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
                layers.accent = colorSpec.colors.accent or {math.min(1, ctab[1] + 0.1), math.min(1, ctab[2] + 0.1), math.min(1, ctab[3] + 0.1), 0.7}
                layers.shadow = colorSpec.colors.shadow or {ctab[1] * 0.6, ctab[2] * 0.6, ctab[3] * 0.6, 0.8}
                layers.detail = colorSpec.colors.detail or {0.8, 0.8, 0.8, 0.5}
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
local function drawPolygon(x, y, polygonShape, color, texture, entityId)
    local vertices = polygonShape.vertices
    if not polygonShape or not color then return end

    local colors = resolveColors(color)
    if not vertices or #vertices < 3 then return end

    local worldVertices = {}
    for i = 1, #vertices do
        local v = vertices[i]
        table.insert(worldVertices, x + v.x)
        table.insert(worldVertices, y + v.y)
    end

    -- Check if this is an asteroid for special rendering
    local asteroid = entityId and ECS.getComponent(entityId, "Asteroid")
    local wreckage = entityId and ECS.getComponent(entityId, "Wreckage")

    if asteroid then
        -- Enhanced asteroid rendering with depth layers

        -- Draw shadow/base layer
        love.graphics.setColor(colors.shadow[1], colors.shadow[2], colors.shadow[3], colors.shadow[4])
        love.graphics.polygon("fill", worldVertices)

        -- Draw main hull (stripes) with slight offset for depth
        love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], colors.stripes[4])
        love.graphics.polygon("fill", worldVertices)

        -- Draw accent highlights for depth and realism
        love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4])
        -- Create highlight vertices (slightly inset)
        local highlightVertices = {}
        for i = 1, #vertices do
            local v = vertices[i]
            local factor = 0.95  -- Slightly inset for highlight
            table.insert(highlightVertices, x + v.x * factor)
            table.insert(highlightVertices, y + v.y * factor)
        end
        love.graphics.polygon("fill", highlightVertices)

        -- Special crystal asteroid glow effect
        if asteroid.asteroidType == "crystal" and asteroid.crystalFormation then
            local glowIntensity = asteroid.crystalFormation.glowIntensity or 0.5

            -- Outer glow
            love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], glowIntensity * 0.2)
            local glowVertices = {}
            for i = 1, #vertices do
                local v = vertices[i]
                local factor = 1.15  -- Larger glow
                table.insert(glowVertices, x + v.x * factor)
                table.insert(glowVertices, y + v.y * factor)
            end
            love.graphics.polygon("fill", glowVertices)

            -- Inner glow
            love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], glowIntensity * 0.4)
            local innerGlowVertices = {}
            for i = 1, #vertices do
                local v = vertices[i]
                local factor = 1.05  -- Smaller inner glow
                table.insert(innerGlowVertices, x + v.x * factor)
                table.insert(innerGlowVertices, y + v.y * factor)
            end
            love.graphics.polygon("fill", innerGlowVertices)

            -- Add sparkle effects
            love.graphics.setColor(1, 1, 1, glowIntensity * 0.8)
            local sparkleCount = 3 + math.floor(glowIntensity * 3)  -- 3-6 sparkles based on intensity
            for i = 1, sparkleCount do
                local angle = (i / sparkleCount) * 2 * math.pi + love.timer.getTime() * (1 + i * 0.5)
                local distance = 15 + math.sin(love.timer.getTime() * 2 + i) * 5
                local sparkleX = x + math.cos(angle) * distance
                local sparkleY = y + math.sin(angle) * distance
                local sparkleSize = 1 + math.sin(love.timer.getTime() * 3 + i * 2) * 0.5

                love.graphics.circle("fill", sparkleX, sparkleY, sparkleSize)
            end
        end

    elseif wreckage then
        -- Wreckage rendering (darker, more damaged appearance)
        love.graphics.setColor(colors.shadow[1] * 0.7, colors.shadow[2] * 0.7, colors.shadow[3] * 0.7, colors.shadow[4])
        love.graphics.polygon("fill", worldVertices)

        love.graphics.setColor(colors.stripes[1] * 0.8, colors.stripes[2] * 0.8, colors.stripes[3] * 0.8, colors.stripes[4])
        love.graphics.polygon("fill", worldVertices)

    else
        -- Standard entity rendering (ships, stations, etc.)
        love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], colors.stripes[4])
        love.graphics.polygon("fill", worldVertices)
    end

    -- Draw texture shapes (works for all entities)
    if texture then
        for field, shapes in pairs(texture) do
            if type(shapes) == "table" and #shapes > 0 then
                for _, shape in ipairs(shapes) do
                    -- Safety check: ensure shape is a table with required properties
                    if type(shape) == "table" then
                        if shape.x and shape.y and shape.r and shape.color and type(shape.color) == "table" and #shape.color >= 3 then
                            love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], shape.color[4] or 1)
                            love.graphics.circle("fill", x + shape.x, y + shape.y, shape.r)
                        elseif shape.x1 and shape.y1 and shape.x2 and shape.y2 and shape.color and type(shape.color) == "table" and #shape.color >= 3 then
                            love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], shape.color[4] or 1)
                            love.graphics.setLineWidth(shape.lineWidth or 3)
                            love.graphics.line(x + shape.x1, y + shape.y1, x + shape.x2, y + shape.y2)
                        end
                    end
                end
            end
        end
    end

    -- Enhanced outline for asteroids
    if asteroid then
        -- Darker outline for asteroids
        love.graphics.setColor(0, 0, 0, colors.stripes[4])
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", worldVertices)

        love.graphics.setColor(colors.stripes[1] * 0.4, colors.stripes[2] * 0.4, colors.stripes[3] * 0.4, colors.stripes[4])
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", worldVertices)

    elseif wreckage then
        -- More damaged outline for wreckage
        love.graphics.setColor(0, 0, 0, colors.stripes[4])
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", worldVertices)

    else
        -- Standard outline
        love.graphics.setColor(0, 0, 0, colors.stripes[4])
        love.graphics.setLineWidth(4)
        love.graphics.polygon("line", worldVertices)

        love.graphics.setColor(colors.stripes[1] * 0.3, colors.stripes[2] * 0.3, colors.stripes[3] * 0.3, colors.stripes[4])
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", worldVertices)
    end

    love.graphics.setLineWidth(1)
end

local function drawDecorativeParts(parts)
    for _, part in ipairs(parts or {}) do
        love.graphics.push()
        if part.x or part.y then
            love.graphics.translate(part.x or 0, part.y or 0)
        end
        local t = love.timer.getTime()
        local r = (part.rot or part.angle or 0) + ((part.spinSpeed or 0) * t)
        if r ~= 0 then
            love.graphics.rotate(r)
        end
        love.graphics.setColor((part.color or {1,1,1,1}))
        if part.type == "circle" then
            love.graphics.circle("fill", 0, 0, part.radius or 10)
        elseif part.type == "ring" then
            love.graphics.setLineWidth(part.width or 8)
            love.graphics.circle("line", 0, 0, part.radius or 12)
            love.graphics.setLineWidth(1)
        elseif part.type == "rect" then
            local w, h = part.width or 20, part.height or 12
            love.graphics.rectangle("fill", -(w/2), -(h/2), w, h)
        elseif part.type == "line" then
            local lw = part.width or 2
            love.graphics.setLineWidth(lw)
            love.graphics.line(part.x1 or 0, part.y1 or 0, part.x2 or 0, part.y2 or 0)
            love.graphics.setLineWidth(1)
        elseif part.type == "polygon" then
            if part.vertices and #part.vertices >= 3 then
                local verts = {}
                for i, v in ipairs(part.vertices) do
                    if type(v) == "table" then
                        table.insert(verts, v.x or 0)
                        table.insert(verts, v.y or 0)
                    else
                        table.insert(verts, v)
                    end
                end
                if #verts >= 6 then
                    love.graphics.polygon("fill", verts)
                end
            end
        elseif part.type == "arc" then
            local lw = part.width or 2
            love.graphics.setLineWidth(lw)
            local sa = part.startAngle or 0
            local ea = part.endAngle or math.pi * 2
            love.graphics.arc("line", 0, 0, part.radius or 20, sa, ea)
            love.graphics.setLineWidth(1)
        elseif part.type == "glow" then
            local rad = part.radius or 14
            love.graphics.circle("fill", 0, 0, rad)
        end
        love.graphics.pop()
    end
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
                -- Regular circle rendering
                if renderable.color then
                    local cols = resolveColors(renderable.color)
                    love.graphics.setColor(cols.stripes[1], cols.stripes[2], cols.stripes[3], cols.stripes[4])
                end
                love.graphics.circle("fill", position.x, position.y, renderable.radius)
                
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", position.x, position.y, renderable.radius)
                love.graphics.setLineWidth(1)
                
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
                    local isStation = ECS.hasComponent(entityId, "StationDetails")
                    if isPlayerDrone then
                        local playerRotation = polygonShape.rotation or 0
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        love.graphics.rotate(playerRotation)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture, entityId)
                        love.graphics.pop()
                    elseif isShip then
                        local enemyRotation = polygonShape.rotation or 0
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        love.graphics.rotate(enemyRotation)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture, entityId)
                        love.graphics.pop()
                    elseif isStation then
                        -- Draw hull, then modular parts for decorative station
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture, entityId)
                        local details = ECS.getComponent(entityId, "StationDetails")
                        if details then
                            drawDecorativeParts(details)
                        end
                        love.graphics.pop()
                        local label = ECS.getComponent(entityId, "StationLabel")
                        if label and label[1] then
                            love.graphics.setColor(1, 1, 1, 0.85)
                            love.graphics.print(label[1], position.x-40, position.y-14, 0, 1.2, 1.2)
                        end
                        
                        -- Draw floating question mark effect
                        local questionMark = ECS.getComponent(entityId, "FloatingQuestionMark")
                        if questionMark then
                            -- Update animation timer (use love.timer.getTime for frame-independent animation)
                            questionMark.time = love.timer.getTime() * questionMark.speed
                            
                            -- Calculate bobbing offset
                            local bobOffset = math.sin(questionMark.time) * questionMark.amplitude
                            
                            -- Position above the station
                            local markX = position.x
                            local markY = position.y - 80 - bobOffset
                            
                            -- Draw question mark with black border and huge size
                            local fontSize = 64
                            local borderSize = 4
                            
                            -- Black border (draw multiple times for thick border)
                            love.graphics.setColor(0, 0, 0, questionMark.color[4])
                            love.graphics.setFont(love.graphics.newFont(fontSize))
                            for i = -borderSize, borderSize do
                                for j = -borderSize, borderSize do
                                    if i ~= 0 or j ~= 0 then
                                        love.graphics.print("?", markX - 16 + i, markY - 16 + j)
                                    end
                                end
                            end
                            
                            -- Bright core
                            love.graphics.setColor(questionMark.color[1], questionMark.color[2], questionMark.color[3], questionMark.color[4])
                            love.graphics.print("?", markX - 16, markY - 16)
                        end
                    else
                        -- Generic polygon: apply entity rotation before drawing so standalone
                        -- polygon entities (like missiles) face their `polygonShape.rotation`.
                        local entRot = polygonShape.rotation or 0
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        love.graphics.rotate(entRot)
                        drawPolygon(0, 0, polygonShape, renderable.color, renderable.texture, entityId)
                        love.graphics.pop()
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

