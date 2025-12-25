--- Refinery Bay System
--- Handles asteroid container bay: detects fully enclosed asteroids and processes them

local Concord = require("lib.concord")
local Items = require("game.items")
local Refinery = require("game.systems.refinery")

local RefineryBaySystem = Concord.system({
    stations = { "refinery_bay", "physics_body" },
    asteroids = { "asteroid", "physics_body" }
})

function RefineryBaySystem:init(world)
    self.world = world
end

-- Build ore recipes lookup from centralized Refinery module
local function getOreRecipes()
    local recipes = {}
    for _, recipe in ipairs(Refinery.getRecipes()) do
        recipes[recipe.inputId] = {
            outputId = recipe.outputId,
            ratio = recipe.ratio,
            timePerUnit = recipe.timePerUnit or 3.0,
        }
    end
    return recipes
end

local ORE_RECIPES = getOreRecipes()


-- Check if an asteroid is fully enclosed in the bay
local function isAsteroidFullyInBay(asteroid, station)
    local bay = station.refinery_bay
    local stationBody = station.physics_body.body
    local asteroidBody = asteroid.physics_body.body

    if not stationBody or not asteroidBody then
        return false
    end

    local stationX, stationY = stationBody:getPosition()
    local asteroidX, asteroidY = asteroidBody:getPosition()
    local asteroidRadius = asteroid.asteroid.radius or 20

    -- Check if asteroid fits in the bay opening (opening height along Y axis)
    if asteroidRadius * 2 > bay.openingWidth then
        return false
    end

    -- Bay center in world coordinates
    local bayCenterX = stationX + bay.bayCenterX
    local bayCenterY = stationY + bay.bayCenterY

    -- Bay bounds for horizontal right-facing bay:
    -- Back wall (left side, closest to station)
    local backWallX = bayCenterX - bay.bayDepth / 2
    -- Opening (right side, farthest from station)
    local openingX = bayCenterX + bay.bayDepth / 2
    -- Vertical bounds
    local topBound = bayCenterY - bay.openingWidth / 2
    local bottomBound = bayCenterY + bay.openingWidth / 2

    -- Asteroid edges
    local asteroidLeft = asteroidX - asteroidRadius
    local asteroidRight = asteroidX + asteroidRadius
    local asteroidTop = asteroidY - asteroidRadius
    local asteroidBottom = asteroidY + asteroidRadius

    -- Asteroid is fully inside when ALL edges are within the bay
    local insideHorizontally = asteroidLeft > backWallX and asteroidRight < openingX
    local insideVertically = asteroidTop > topBound and asteroidBottom < bottomBound

    -- DEBUG: Print detection info
    if asteroidLeft > backWallX - 50 then -- Only print for nearby asteroids
        print(string.format("[Bay] Asteroid at (%.0f, %.0f) r=%.0f | Bay X: %.0f to %.0f | Y: %.0f to %.0f | H:%s V:%s",
            asteroidX, asteroidY, asteroidRadius,
            backWallX, openingX, topBound, bottomBound,
            tostring(insideHorizontally), tostring(insideVertically)))
    end

    return insideHorizontally and insideVertically
end

-- Start processing an asteroid in the bay
local function startProcessingAsteroid(station, asteroid, ecsWorld)
    local bay = station.refinery_bay
    local asteroidComp = asteroid.asteroid

    -- Already processing something
    if bay.processingJob then
        bay.rejectedFlash = 0.5
        return false
    end

    local oreId = asteroidComp.oreId
    local oreVolume = asteroidComp.volume or 1

    -- Check if this asteroid has ore we can process
    local recipe = ORE_RECIPES[oreId]
    if not recipe then
        -- No ore or unknown ore type - still accept but minimal yield
        oreId = "iron"                                               -- Default to iron processing
        recipe = ORE_RECIPES.iron
        oreVolume = math.max(1, math.floor(asteroidComp.volume / 4)) -- Reduced yield for non-ore asteroids
    end

    -- Apply efficiency bonus
    local effectiveVolume = math.floor(oreVolume * bay.efficiencyBonus)

    -- Calculate output quantity
    local outputQuantity = math.max(1, math.floor(effectiveVolume / recipe.ratio))

    -- Calculate processing time with multiplier
    local totalTime = outputQuantity * recipe.timePerUnit * bay.timeMultiplier

    -- Create the processing job
    bay.processingJob = {
        oreId = oreId,
        oreVolume = effectiveVolume,
        outputId = recipe.outputId,
        quantity = outputQuantity,
        progress = 0,
        totalTime = totalTime,
        startTime = love.timer.getTime(),
    }

    -- Visual feedback
    bay.acceptedFlash = 1.0

    -- Spawn floating text
    local asteroidBody = asteroid.physics_body.body
    if asteroidBody and ecsWorld then
        local ax, ay = asteroidBody:getPosition()
        local outputDef = Items.get(recipe.outputId)
        local outputName = outputDef and outputDef.name or recipe.outputId
        local msg = "Processing: " .. outputQuantity .. " " .. outputName
        local textEntity = ecsWorld:newEntity()
        textEntity:give("floating_text", msg, ax, ay, { color = { 0.4, 1.0, 0.5, 1.0 }, duration = 2.0 })
    end

    -- Destroy the asteroid
    if asteroid.physics_body and asteroid.physics_body.body then
        asteroid.physics_body.body:destroy()
    end
    asteroid:destroy()

    return true
end



function RefineryBaySystem:update(dt)
    self.ecsWorld = self:getWorld()

    -- Update processing jobs and visual feedback
    for _, station in ipairs(self.stations) do
        local bay = station.refinery_bay

        -- Update visual feedback timers
        if bay.acceptedFlash > 0 then
            bay.acceptedFlash = math.max(0, bay.acceptedFlash - dt * 2)
        end
        if bay.rejectedFlash > 0 then
            bay.rejectedFlash = math.max(0, bay.rejectedFlash - dt * 2)
        end

        -- Update processing job progress
        if bay.processingJob then
            bay.processingJob.progress = bay.processingJob.progress + dt
        end

        -- Check for asteroids that are fully in the bay
        for _, asteroid in ipairs(self.asteroids) do
            if asteroid and asteroid.physics_body and asteroid.physics_body.body then
                if isAsteroidFullyInBay(asteroid, station) then
                    startProcessingAsteroid(station, asteroid, self.ecsWorld)
                end
            end
        end
    end
end

-- Get the current bay processing status for UI
function RefineryBaySystem.getBayStatus(station)
    if not station or not station.refinery_bay then
        return nil
    end

    local bay = station.refinery_bay
    if not bay.processingJob then
        return { processing = false }
    end

    local job = bay.processingJob
    local progress = math.min(1, job.progress / job.totalTime)
    local remaining = math.max(0, job.totalTime - job.progress)

    return {
        processing = true,
        outputId = job.outputId,
        quantity = job.quantity,
        progress = progress,
        remainingTime = remaining,
        complete = job.progress >= job.totalTime,
    }
end

-- Check if point (world coords) is in the bay or storage area
local function toLocalCoords(station, x, y)
    if not station or not station.refinery_bay or not station.physics_body then
        return nil
    end

    local body = station.physics_body.body
    if not body then
        return nil
    end

    local sx, sy = body:getPosition()
    local angle = body:getAngle()
    local dx = x - sx
    local dy = y - sy
    local c = math.cos(-angle)
    local s = math.sin(-angle)
    local lx = dx * c - dy * s
    local ly = dx * s + dy * c

    return lx, ly
end

local function getBayRects(bay, station)
    local radius = (station.space_station and station.space_station.radius) or 200
    local bayCenterX = bay.bayCenterX or (radius + 50)
    local bayCenterY = bay.bayCenterY or 0
    local bayWidth = bay.openingWidth or 50
    local bayDepth = bay.bayDepth or 100

    local bayRect = {
        x = bayCenterX - bayDepth / 2,
        y = bayCenterY - bayWidth / 2,
        w = bayDepth,
        h = bayWidth
    }

    local wallThickness = 10
    local storageWidth = 30
    local storageHeight = bayWidth + 10
    local storageX = bayCenterX - bayDepth / 2 - wallThickness - storageWidth - 5
    local storageY = bayCenterY - storageHeight / 2
    local storageRect = {
        x = storageX,
        y = storageY,
        w = storageWidth,
        h = storageHeight
    }

    return bayRect, storageRect
end

local function pointInRect(lx, ly, rect)
    return lx >= rect.x and lx <= rect.x + rect.w and ly >= rect.y and ly <= rect.y + rect.h
end

function RefineryBaySystem.isPointInBay(station, x, y)
    local lx, ly = toLocalCoords(station, x, y)
    if not lx then
        return false
    end

    local bay = station.refinery_bay
    local bayRect, storageRect = getBayRects(bay, station)
    local inBay = pointInRect(lx, ly, bayRect)
    local inStorage = pointInRect(lx, ly, storageRect)

    return inBay or inStorage
end

function RefineryBaySystem.isPointInBayOpening(station, x, y)
    local lx, ly = toLocalCoords(station, x, y)
    if not lx then
        return false
    end

    local bay = station.refinery_bay
    local bayRect = getBayRects(bay, station)
    return pointInRect(lx, ly, bayRect)
end

-- Try to collect job at specific world coordinates
function RefineryBaySystem.tryCollectAt(ecsWorld, x, y, ship)
    -- Iterate all entities with refinery_bay
    -- Since we can't easily query Concord outside a system loop, we'll assume we pass the station or iterate manually
    -- Ideally, the caller identifies the station. BUT Space.lua knows the hovered station.
    -- If Space.lua passes the station, we can just check that one.
    -- If not, we have to find it.

    -- Logic moved to Space.lua: Space finds hovered station, then calls collectBayJob if isPointInBay returns true.
    return false
end

-- Draw Tooltip on HUD layer
function RefineryBaySystem:drawHud()
    local mouseWorld = self.world:getResource("mouse_world")
    if not mouseWorld then return end

    local view = self.world:getResource("camera_view")
    if not view then return end

    local wx, wy = mouseWorld.x, mouseWorld.y
    local camX, camY = view.camX or 0, view.camY or 0
    local zoom = view.zoom or 1

    -- Iterate all stations
    for i = 1, self.stations.size do
        local station = self.stations[i]

        if RefineryBaySystem.isPointInBayOpening(station, wx, wy) then
            local bay = station.refinery_bay
            local body = station.physics_body.body
            local sx, sy = body:getPosition()
            local angle = body:getAngle()

            -- Calculate Tooltip Position (Above the bay)
            -- Bay local center
            local radius = (station.space_station and station.space_station.radius) or 200
            local bayCenterX = bay.bayCenterX or (radius + 50)
            local bayCenterY = bay.bayCenterY or 0
            local bayWidth = bay.openingWidth or 50
            local bayDepth = bay.bayDepth or 100

            -- Position at top-center of bay
            local localTx = bayCenterX
            local localTy = bayCenterY - bayWidth / 2 - 20

            -- Rotate to world
            local c = math.cos(angle)
            local s = math.sin(angle)
            local worldTx = sx + localTx * c - localTy * s
            local worldTy = sy + localTx * s + localTy * c

            -- Project to Screen
            local screenX = (worldTx - camX) * zoom
            local screenY = (worldTy - camY) * zoom

            -- Draw Tooltip
            love.graphics.push("all")

            local tooltipW = 220
            local tooltipH = 100 -- grows with content

            -- Center horizontally on screenX, place above screenY
            local tx = screenX - tooltipW / 2
            local ty = screenY - tooltipH - 20

            -- Keep on screen
            local sw, sh = love.graphics.getDimensions()
            if tx < 10 then tx = 10 end
            if tx + tooltipW > sw - 10 then tx = sw - tooltipW - 10 end
            if ty < 10 then ty = screenY + 40 end -- Flip down if off top

            -- Gather Data
            local statusText = "Ready for Input"
            local progress = 0
            local contentText = "Empty"
            local timeText = ""
            local outputText = ""
            local isReady = false

            if bay.processingJob then
                local job = bay.processingJob
                progress = job.progress / job.totalTime
                isReady = progress >= 1

                if isReady then
                    statusText = "COMPLETED"
                else
                    statusText = "PROCESSING"
                    timeText = string.format("%.1fs remaining", math.max(0, job.totalTime - job.progress))
                end

                local outDef = Items.get(job.outputId)
                local outName = (outDef and outDef.name) or job.outputId
                outputText = string.format("Output: %s x%d", outName, job.quantity)
            end

            -- Calculate height
            tooltipH = 40
            if bay.processingJob then
                tooltipH = tooltipH + 65
                if isReady then tooltipH = tooltipH + 20 end
            else
                tooltipH = tooltipH + 20
            end

            -- Re-adjust Y for dynamic height
            if ty == screenY - 100 - 20 then -- If it was default (top)
                ty = screenY - tooltipH - 20
                if ty < 10 then ty = screenY + 40 end
            end

            -- Draw Background
            love.graphics.setColor(0.05, 0.08, 0.1, 0.95)
            love.graphics.rectangle("fill", tx, ty, tooltipW, tooltipH, 4)
            love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tx, ty, tooltipW, tooltipH, 4)

            -- Draw Content
            local py = ty + 8
            local px = tx + 10

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(love.graphics.newFont(14))
            love.graphics.print("Refinery Bay", px, py)
            py = py + 20

            love.graphics.setFont(love.graphics.newFont(12))

            if bay.processingJob then
                -- Status
                if isReady then
                    love.graphics.setColor(0.4, 1.0, 0.4, 1)
                else
                    love.graphics.setColor(1.0, 0.8, 0.2, 1)
                end
                love.graphics.print(statusText, px, py)
                py = py + 16

                if not isReady then
                    -- Progress Bar
                    love.graphics.setColor(0.2, 0.2, 0.2, 1)
                    love.graphics.rectangle("fill", px, py, tooltipW - 20, 6)
                    love.graphics.setColor(0.4, 0.8, 1.0, 1)
                    love.graphics.rectangle("fill", px, py, (tooltipW - 20) * math.min(1, progress), 6)
                    py = py + 10

                    love.graphics.setColor(0.8, 0.8, 0.8, 1)
                    love.graphics.print(timeText, px, py)
                    py = py + 16
                end

                love.graphics.setColor(0.9, 0.9, 0.9, 1)
                love.graphics.print(outputText, px, py)
                py = py + 18

                if isReady then
                    love.graphics.setColor(0.5, 1.0, 0.5, 1)
                    love.graphics.print("CLICK TO CLAIM", px + 30, py)
                end
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.print("Waiting for asteroid...", px, py)
            end

            love.graphics.pop()

            -- Only show for one station (assumes no overlap)
            break
        end
    end
end

-- Collect completed bay job (called from refinery UI)
function RefineryBaySystem.collectBayJob(station, ship)
    if not station or not station.refinery_bay then
        return false, "Invalid station"
    end

    local bay = station.refinery_bay
    if not bay.processingJob then
        return false, "No job to collect"
    end

    local job = bay.processingJob
    if job.progress < job.totalTime then
        return false, "Job not complete"
    end

    -- Add ingots to ship cargo
    if ship and ship.cargo_hold and ship.cargo then
        local Inventory = require("game.inventory")
        local outputDef = Items.get(job.outputId)
        local unitVolume = (outputDef and outputDef.unitVolume) or 1
        local totalVolume = job.quantity * unitVolume

        local remaining = Inventory.addToSlots(ship.cargo_hold.slots, job.outputId, totalVolume)
        if remaining > 0 then
            return false, "Not enough cargo space"
        end

        ship.cargo.used = Inventory.totalVolume(ship.cargo_hold.slots)
    end

    -- Clear the job
    local outputName = Items.get(job.outputId)
    outputName = outputName and outputName.name or job.outputId
    local msg = "Collected " .. job.quantity .. " " .. outputName
    bay.processingJob = nil

    return true, msg
end

return RefineryBaySystem
