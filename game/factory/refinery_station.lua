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

    return e
end

return refinery_station
