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

    local e = ecsWorld:newEntity()
        :give("physics_body", body, shape, fixture)
        :give("renderable", "refinery_station", { 0.85, 0.55, 0.25, 1.0 })
        :give("space_station", stationType, radius, dockingPoints)
        :give("refinery_queue", 3) -- 3 queue slots

    fixture:setUserData(e)

    return e
end

return refinery_station
