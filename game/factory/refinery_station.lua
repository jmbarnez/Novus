local refinery_station = {}

local unpack = unpack or table.unpack

function refinery_station.createRefineryStation(ecsWorld, physicsWorld, x, y)
    local stationType = "refinery"
    local radius = 200 -- Smaller than main hub

    local body = love.physics.newBody(physicsWorld, x, y, "static")

    -- Create a hexagonal shape for the refinery
    local points = {}
    local segments = 6
    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2 - math.pi / 2
        table.insert(points, math.cos(angle) * radius)
        table.insert(points, math.sin(angle) * radius)
    end

    local shape = love.physics.newPolygonShape(unpack(points))
    local fixture = love.physics.newFixture(body, shape, 1)
    fixture:setRestitution(0.1)
    fixture:setFriction(0.8)
    fixture:setCategory(3)

    -- Define docking points around the station (4 docks for smaller station)
    local dockingPoints = {}
    local numDocks = 4
    for i = 0, numDocks - 1 do
        local dockAngle = (i / numDocks) * math.pi * 2
        local dockDistance = radius + 60
        table.insert(dockingPoints, {
            x = math.cos(dockAngle) * dockDistance,
            y = math.sin(dockAngle) * dockDistance,
            angle = dockAngle,
            occupied = false,
            id = i + 1,
        })
    end

    -- Level 1 refinery work orders
    local refineryLevel = 1
    local workOrders = {
        {
            id = "refine_iron_lvl1",
            levelRequired = 1,
            recipeInputId = "iron",
            outputId = "iron_ingot",
            amount = 10,
            rewardCredits = 150,
            description = "Smelt 10 Iron Ingots",
            accepted = false,
            completed = false,
            rewarded = false,
            turnInRequired = true,
            current = 0,
        },
        {
            id = "refine_mithril_lvl1",
            levelRequired = 1,
            recipeInputId = "mithril",
            outputId = "mithril_ingot",
            amount = 6,
            rewardCredits = 320,
            description = "Smelt 6 Mithril Ingots",
            accepted = false,
            completed = false,
            rewarded = false,
            turnInRequired = true,
            current = 0,
        },
    }

    local e = ecsWorld:newEntity()
        :give("physics_body", body, shape, fixture)
        :give("renderable", "refinery_station", { 0.85, 0.55, 0.25, 1.0 })
        :give("space_station", stationType, radius, dockingPoints)
        :give("refinery_queue", 3, refineryLevel, workOrders) -- 3 queue slots, level + work orders

    fixture:setUserData(e)

    -- Create the asteroid container bay (U-shaped pocket)
    -- Angle 0 = facing right, bay attached to right side of station
    local bayAngle = 0
    local bayOpeningWidth = 50 -- Level 1: only small asteroids fit (radius <= 25)
    local bayDepth = 100       -- How deep the bay extends
    local wallThickness = 10

    -- Calculate bay position (attached to right side of station, facing right)
    local bayOffsetDist = radius + bayDepth / 2
    local bayCenterX = math.cos(bayAngle) * bayOffsetDist -- To the right
    local bayCenterY = math.sin(bayAngle) * bayOffsetDist -- Centered vertically (0)

    -- Top wall of bay (runs horizontally along X, at negative Y)
    local topWallShape = love.physics.newRectangleShape(
        bayCenterX,
        bayCenterY - bayOpeningWidth / 2 - wallThickness / 2,
        bayDepth,
        wallThickness
    )
    local topWallFixture = love.physics.newFixture(body, topWallShape, 1)
    topWallFixture:setRestitution(0.3)
    topWallFixture:setFriction(0.5)
    topWallFixture:setCategory(3)
    topWallFixture:setUserData(e)

    -- Bottom wall of bay (runs horizontally along X, at positive Y)
    local bottomWallShape = love.physics.newRectangleShape(
        bayCenterX,
        bayCenterY + bayOpeningWidth / 2 + wallThickness / 2,
        bayDepth,
        wallThickness
    )
    local bottomWallFixture = love.physics.newFixture(body, bottomWallShape, 1)
    bottomWallFixture:setRestitution(0.3)
    bottomWallFixture:setFriction(0.5)
    bottomWallFixture:setCategory(3)
    bottomWallFixture:setUserData(e)

    -- Back wall of bay (vertical, on left side closest to station)
    local backWallShape = love.physics.newRectangleShape(
        bayCenterX - bayDepth / 2 - wallThickness / 2,
        bayCenterY,
        wallThickness,
        bayOpeningWidth + wallThickness * 2
    )
    local backWallFixture = love.physics.newFixture(body, backWallShape, 1)
    backWallFixture:setRestitution(0.3)
    backWallFixture:setFriction(0.5)
    backWallFixture:setCategory(3)
    backWallFixture:setUserData(e)

    -- Sensor at the bay opening (right side, facing outward)
    local sensorShape = love.physics.newRectangleShape(
        bayCenterX + bayDepth / 2 - 5, -- Just inside the opening (right side)
        bayCenterY,
        10,
        bayOpeningWidth - 10 -- Slightly narrower than opening
    )
    local sensorFixture = love.physics.newFixture(body, sensorShape, 0)
    sensorFixture:setSensor(true)
    sensorFixture:setUserData({ type = "bay_sensor", station = e })

    -- Give the entity the refinery_bay component
    e:give("refinery_bay", bayOpeningWidth, bayDepth, bayAngle)
    e.refinery_bay.sensorFixture = sensorFixture
    e.refinery_bay.bayCenterX = bayCenterX
    e.refinery_bay.bayCenterY = bayCenterY
    e.refinery_bay.openingFacesOutward = true -- Flag for detection logic

    return e
end

return refinery_station
