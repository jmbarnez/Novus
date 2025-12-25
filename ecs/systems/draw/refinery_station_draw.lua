local Utils = require("ecs.systems.draw.render_utils")
local Items = require("game.items")
local Items = require("game.items")

local RefineryStationDraw = {}

local function drawStructuralRing(radius, lineWidth, color)
    love.graphics.push("all")
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.circle("line", 0, 0, radius)
    love.graphics.pop()
end

local function drawProcessingPipe(innerR, outerR, angle, width, color)
    love.graphics.push("all")
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    local x1 = math.cos(angle) * innerR
    local y1 = math.sin(angle) * innerR
    local x2 = math.cos(angle) * outerR
    local y2 = math.sin(angle) * outerR
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.pop()
end

local function drawDockRingIfNear(ctx, stationX, stationY, dockingRange)
    local range = dockingRange or 0
    if range <= 0 then
        return
    end

    local baseAlpha = 0.10
    local brightAlpha = 0.95
    local t = 0

    local playerShip = ctx and ctx.playerShip
    local body = playerShip and playerShip.physics_body and playerShip.physics_body.body
    if body then
        local px, py = body:getPosition()
        local dx, dy = px - stationX, py - stationY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= range then
            t = 1
        else
            local falloffRange = range * 1.05
            t = math.max(0, math.min(1, 1 - dist / falloffRange))
            t = t * t -- smoother ease
        end
    end

    local alpha = baseAlpha + (brightAlpha - baseAlpha) * t

    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    -- Orange docking ring for refinery stations
    love.graphics.setColor(0.95, 0.55, 0.15, alpha)
    love.graphics.circle("line", 0, 0, range)
    love.graphics.pop()
end

function RefineryStationDraw.draw(ctx, e, body, shape, x, y, angle)
    local radius = (e.space_station and e.space_station.radius) or 200
    local dockingPoints = (e.space_station and e.space_station.dockingPoints) or {}

    -- Cull if off-screen
    if ctx.viewLeft then
        local cullRadius = radius + 100
        if x + cullRadius < ctx.viewLeft - ctx.cullPad or x - cullRadius > ctx.viewRight + ctx.cullPad
            or y + cullRadius < ctx.viewTop - ctx.cullPad or y - cullRadius > ctx.viewBottom + ctx.cullPad then
            return
        end
    end

    local time = love.timer.getTime()

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    -- Main body: heavy hex plate
    love.graphics.push("all")
    love.graphics.setColor(0.20, 0.18, 0.14, 1.0)
    love.graphics.polygon("fill", shape:getPoints())
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.65, 0.50, 0.32, 0.9)
    love.graphics.polygon("line", shape:getPoints())
    love.graphics.pop()

    -- Reinforced frame (offset hex)
    love.graphics.push("all")
    love.graphics.setColor(0.32, 0.26, 0.20, 0.9)
    love.graphics.setLineWidth(5)
    for i = 1, 6 do
        local ang = (i / 6) * math.pi * 2
        local x1 = math.cos(ang) * radius * 0.92
        local y1 = math.sin(ang) * radius * 0.92
        local x2 = math.cos(ang + math.pi / 3) * radius * 0.92
        local y2 = math.sin(ang + math.pi / 3) * radius * 0.92
        love.graphics.line(x1, y1, x2, y2)
    end
    love.graphics.pop()

    -- Structural ribs (6 heavy beams)
    for i = 0, 5 do
        local ang = (i / 6) * math.pi * 2
        drawProcessingPipe(radius * 0.28, radius * 0.78, ang, 6, { 0.55, 0.40, 0.25, 0.8 })
    end

    -- Fuel/ore tanks (three industrial cylinders)
    love.graphics.push("all")
    love.graphics.setColor(0.40, 0.36, 0.32, 1.0)
    local tankR = radius * 0.18
    local tankOffset = radius * 0.42
    local tankPositions = {
        { -tankOffset, -radius * 0.08 },
        { tankOffset,  -radius * 0.12 },
        { 0,           radius * 0.26 },
    }
    for _, pos in ipairs(tankPositions) do
        love.graphics.circle("fill", pos[1], pos[2], tankR)
        love.graphics.setColor(0.75, 0.60, 0.35, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", pos[1], pos[2], tankR)
        love.graphics.setColor(0.40, 0.36, 0.32, 1.0)
    end
    love.graphics.pop()

    -- Conveyor deck (horizontal band)
    love.graphics.push("all")
    love.graphics.setColor(0.18, 0.16, 0.12, 0.9)
    love.graphics.rectangle("fill", -radius * 0.70, -radius * 0.10, radius * 1.40, radius * 0.20, 6)
    love.graphics.setColor(0.70, 0.55, 0.32, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -radius * 0.70, -radius * 0.10, radius * 1.40, radius * 0.20, 6)
    love.graphics.pop()

    -- Heat exchanger fins (8 short blades)
    love.graphics.push("all")
    love.graphics.setColor(0.80, 0.65, 0.38, 0.85)
    love.graphics.setLineWidth(3)
    for i = 0, 7 do
        local ang = (i / 8) * math.pi * 2 + math.pi / 8
        local inner = radius * 0.20
        local outer = radius * 0.34
        love.graphics.line(
            math.cos(ang) * inner, math.sin(ang) * inner,
            math.cos(ang) * outer, math.sin(ang) * outer
        )
    end
    love.graphics.pop()

    -- Furnace core (layered, animated glow)
    local furnacePulse = 0.6 + 0.4 * math.sin(time * 2)
    love.graphics.push("all")
    love.graphics.setColor(0.30, 0.22, 0.16, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.26)
    love.graphics.setColor(0.80, 0.45, 0.18, furnacePulse * 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.20)
    love.graphics.setColor(1.00, 0.72, 0.32, furnacePulse * 0.7)
    love.graphics.circle("fill", 0, 0, radius * 0.14)
    love.graphics.setColor(1.00, 0.85, 0.55, furnacePulse * 0.5)
    love.graphics.circle("line", 0, 0, radius * 0.20)
    love.graphics.pop()

    -- Vent steam effects (retain but tie to new geometry)
    love.graphics.push("all")
    for i = 0, 5 do
        local ventAngle = (i / 6) * math.pi * 2 + time * 0.2
        local ventDist = radius * 0.66
        local vx = math.cos(ventAngle) * ventDist
        local vy = math.sin(ventAngle) * ventDist
        local steamAlpha = 0.18 + 0.14 * math.sin((time * 4 + i) * math.pi)
        love.graphics.setColor(0.92, 0.88, 0.82, steamAlpha)
        love.graphics.circle("fill", vx, vy, 6)
    end
    love.graphics.pop()

    -- Asteroid container bay (U-shaped pocket extending to the right)
    if e.refinery_bay then
        local bay = e.refinery_bay
        local bayCenterX = bay.bayCenterX or (radius + 50)
        local bayCenterY = bay.bayCenterY or 0
        local bayWidth = bay.openingWidth or 50 -- Height of opening (Y axis)
        local bayDepth = bay.bayDepth or 100    -- Depth extends along X axis
        local wallThickness = 10

        love.graphics.push("all")

        -- Bay interior (dark shadowed area) - horizontal rectangle
        love.graphics.setColor(0.08, 0.06, 0.05, 0.95)
        love.graphics.rectangle("fill",
            bayCenterX - bayDepth / 2,
            bayCenterY - bayWidth / 2,
            bayDepth,
            bayWidth
        )

        -- Processing glow when job is active
        if bay.processingJob then
            local progress = bay.processingJob.progress / bay.processingJob.totalTime
            local glowPulse = 0.3 + 0.3 * math.sin(time * 3)
            love.graphics.setColor(0.9, 0.5, 0.1, glowPulse * (0.3 + progress * 0.4))
            love.graphics.rectangle("fill",
                bayCenterX - bayDepth / 2 + 5,
                bayCenterY - bayWidth / 2 + 5,
                bayDepth - 10,
                bayWidth - 10,
                4
            )
        end

        -- Acceptance flash (green pulse when asteroid accepted)
        if bay.acceptedFlash > 0 then
            love.graphics.setColor(0.2, 1.0, 0.3, bay.acceptedFlash * 0.6)
            love.graphics.rectangle("fill",
                bayCenterX - bayDepth / 2,
                bayCenterY - bayWidth / 2,
                bayDepth,
                bayWidth
            )
        end

        -- Rejection flash (red pulse when asteroid too big)
        if bay.rejectedFlash > 0 then
            love.graphics.setColor(1.0, 0.2, 0.2, bay.rejectedFlash * 0.6)
            love.graphics.rectangle("fill",
                bayCenterX - bayDepth / 2,
                bayCenterY - bayWidth / 2,
                bayDepth,
                bayWidth
            )
        end

        -- Top wall (horizontal, runs along X at negative Y)
        love.graphics.setColor(0.35, 0.28, 0.22, 1.0)
        love.graphics.rectangle("fill",
            bayCenterX - bayDepth / 2,
            bayCenterY - bayWidth / 2 - wallThickness,
            bayDepth,
            wallThickness
        )
        love.graphics.setColor(0.55, 0.45, 0.35, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line",
            bayCenterX - bayDepth / 2,
            bayCenterY - bayWidth / 2 - wallThickness,
            bayDepth,
            wallThickness
        )

        -- Bottom wall (horizontal, runs along X at positive Y)
        love.graphics.setColor(0.35, 0.28, 0.22, 1.0)
        love.graphics.rectangle("fill",
            bayCenterX - bayDepth / 2,
            bayCenterY + bayWidth / 2,
            bayDepth,
            wallThickness
        )
        love.graphics.setColor(0.55, 0.45, 0.35, 0.8)
        love.graphics.rectangle("line",
            bayCenterX - bayDepth / 2,
            bayCenterY + bayWidth / 2,
            bayDepth,
            wallThickness
        )

        -- Back wall (vertical, on left side closest to station)
        love.graphics.setColor(0.30, 0.24, 0.18, 1.0)
        love.graphics.rectangle("fill",
            bayCenterX - bayDepth / 2 - wallThickness,
            bayCenterY - bayWidth / 2 - wallThickness,
            wallThickness,
            bayWidth + wallThickness * 2
        )
        love.graphics.setColor(0.50, 0.40, 0.30, 0.8)
        love.graphics.rectangle("line",
            bayCenterX - bayDepth / 2 - wallThickness,
            bayCenterY - bayWidth / 2 - wallThickness,
            wallThickness,
            bayWidth + wallThickness * 2
        )

        -- Guide rails at opening (right side, facing outward)
        love.graphics.setColor(0.65, 0.55, 0.40, 0.9)
        love.graphics.setLineWidth(3)
        -- Top guide
        love.graphics.line(
            bayCenterX + bayDepth / 2 - 10,
            bayCenterY - bayWidth / 2 - wallThickness / 2,
            bayCenterX + bayDepth / 2 + 15,
            bayCenterY - bayWidth / 2 - wallThickness / 2
        )
        -- Bottom guide
        love.graphics.line(
            bayCenterX + bayDepth / 2 - 10,
            bayCenterY + bayWidth / 2 + wallThickness / 2,
            bayCenterX + bayDepth / 2 + 15,
            bayCenterY + bayWidth / 2 + wallThickness / 2
        )

        -- Size indicator marks on opening (right side)
        love.graphics.setColor(0.7, 0.6, 0.4, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(
            bayCenterX + bayDepth / 2 + 5,
            bayCenterY - bayWidth / 2 + 5,
            bayCenterX + bayDepth / 2 + 5,
            bayCenterY + bayWidth / 2 - 5
        )

        -- Output storage compartment (between bay and station)
        local storageWidth = 30
        local storageHeight = bayWidth + 10
        local storageX = bayCenterX - bayDepth / 2 - wallThickness - storageWidth - 5
        local storageY = bayCenterY - storageHeight / 2

        -- Storage compartment background
        love.graphics.setColor(0.15, 0.12, 0.10, 1.0)
        love.graphics.rectangle("fill", storageX, storageY, storageWidth, storageHeight, 4)

        -- Storage frame
        love.graphics.setColor(0.45, 0.38, 0.30, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", storageX, storageY, storageWidth, storageHeight, 4)

        -- Storage glow when items ready to collect
        if bay.processingJob and bay.processingJob.progress >= bay.processingJob.totalTime then
            local readyPulse = 0.5 + 0.5 * math.sin(time * 4)
            love.graphics.setColor(0.2, 0.9, 0.3, readyPulse * 0.7)
            love.graphics.rectangle("fill", storageX + 3, storageY + 3, storageWidth - 6, storageHeight - 6, 3)
        end


        -- Tooltip and Hover Interaction
        -- Check if mouse is hovering over the bay or storage compartment
        if ctx.mouse_world then
            local mx, my = ctx.mouse_world.x, ctx.mouse_world.y

            -- Transform world mouse to station-local space
            local dx = mx - x
            local dy = my - y
            local c = math.cos(angle)
            local s = math.sin(angle)
            local lx = dx * c + dy * s
            local ly = -dx * s + dy * c

            -- Hit test variables
            local bayRect = {
                x = bayCenterX - bayDepth / 2,
                y = bayCenterY - bayWidth / 2,
                w = bayDepth,
                h = bayWidth
            }
            local storageRect = {
                x = storageX, -- Calculated above
                y = storageY,
                w = storageWidth,
                h = storageHeight
            }

            local inBay = lx >= bayRect.x and lx <= bayRect.x + bayRect.w and ly >= bayRect.y and
                ly <= bayRect.y + bayRect.h
            local inStorage = lx >= storageRect.x and lx <= storageRect.x + storageRect.w and ly >= storageRect.y and
                ly <= storageRect.y + storageRect.h

            if inBay or inStorage then
                -- Draw hover highlight (in world space)
                love.graphics.setColor(1, 1, 1, 0.1)
                if inBay then
                    love.graphics.rectangle("fill", bayRect.x, bayRect.y, bayRect.w, bayRect.h)
                else
                    love.graphics.rectangle("fill", storageRect.x, storageRect.y, storageRect.w, storageRect.h)
                end
            end
        end

        love.graphics.pop()
    end

    -- Docking distance ring (cyan) only when player is close enough
    drawDockRingIfNear(ctx, x, y, radius * 1.4)

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return RefineryStationDraw
