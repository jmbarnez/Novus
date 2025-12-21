local space_station = {}

local unpack = unpack or table.unpack

function space_station.createSpaceStation(ecsWorld, physicsWorld, x, y, stationType)
    stationType = stationType or "hub"
    local radius = 400 -- Enormous main hub

    local body = love.physics.newBody(physicsWorld, x, y, "static")

    -- Create an octagonal shape for the main station body
    local points = {}
    local segments = 8
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

    -- Define docking points around the station
    local dockingPoints = {}
    local numDocks = 8
    for i = 0, numDocks - 1 do
        local dockAngle = (i / numDocks) * math.pi * 2
        local dockDistance = radius + 80
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
        :give("renderable", "space_station", { 0.55, 0.65, 0.75, 1.0 })
        :give("space_station", stationType, radius, dockingPoints)

    fixture:setUserData(e)

    return e
end

return space_station
