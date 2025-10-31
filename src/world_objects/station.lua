local Components = require('src.components')
local StationDesigns = require('src.station_designs')

local StationPrefab = {}

local function regularPolygon(sides, radius)
    local verts = {}
    local angleStep = (2 * math.pi) / sides
    for i = 1, sides do
        local angle = (i - 1) * angleStep
        table.insert(verts, {x = math.cos(angle) * radius, y = math.sin(angle) * radius})
    end
    return verts
end

-- Build simple decorative parts from a detail definition (subset of procedural builder)
local function buildStationDetails(hullRadius, detailDef)
    local parts = {}
    if not detailDef then return parts end

    local function add(part)
        if part then table.insert(parts, part) end
    end

    if detailDef.modules then
        for _, module in ipairs(detailDef.modules) do
            local moduleType = module.type or module.kind
            if moduleType == "ring" then
                add({ type = "ring", radius = module.radius or hullRadius, width = module.width or 10, color = module.color or {0.68,0.82,1,0.32}, spinSpeed = module.spinSpeed })
            elseif moduleType == "disc" or moduleType == "core" then
                add({ type = "circle", radius = module.radius or (hullRadius * 0.3), color = module.color or {1,1,1,0.3}, spinSpeed = module.spinSpeed })
            elseif moduleType == "spokes" then
                local count = module.count or 4
                local inner = module.innerRadius or (hullRadius * 0.2)
                local outer = module.outerRadius or hullRadius
                local width = module.width or 8
                local offset = module.angleOffset or 0
                local len = outer - inner
                for i = 1, count do
                    local angle = offset + (i - 1) * ((2 * math.pi) / count)
                    add({ type = "rect", x = math.cos(angle) * (inner + len / 2), y = math.sin(angle) * (inner + len / 2), width = len, height = width, rot = angle, color = module.color or {0.75,0.85,1,0.35}, spinSpeed = module.spinSpeed })
                end
            elseif moduleType == "arms" then
                local count = module.count or 3
                local radius = module.radius or (hullRadius + 12)
                local length = module.length or 40
                local width = module.width or 12
                local offset = module.angleOffset or 0
                for i = 1, count do
                    local angle = offset + (i - 1) * ((2 * math.pi) / count)
                    add({ type = "rect", x = math.cos(angle) * radius, y = math.sin(angle) * radius, width = length, height = width, rot = angle, color = module.color or {0.6,0.75,0.95,0.5}, spinSpeed = module.spinSpeed })
                    if module.capRadius then
                        local tipDistance = radius + (module.capOffset or (length / 2))
                        add({ type = "circle", x = math.cos(angle) * tipDistance, y = math.sin(angle) * tipDistance, radius = module.capRadius, color = module.capColor or module.color or {0.6,0.75,0.95,0.5} })
                    end
                end
            elseif moduleType == "panels" then
                local count = module.count or 4
                local radius = module.radius or (hullRadius + 18)
                local width = module.width or 48
                local height = module.height or 14
                local offset = module.angleOffset or 0
                for i = 1, count do
                    local angle = offset + (i - 1) * ((2 * math.pi) / count)
                    add({ type = "rect", x = math.cos(angle) * radius, y = math.sin(angle) * radius, width = width, height = height, rot = angle, color = module.color or {0.3,0.7,1,0.46}, spinSpeed = module.spinSpeed })
                end
            elseif moduleType == "pods" then
                local count = module.count or 4
                local radius = module.radius or (hullRadius + 40)
                local sides = module.sides or 6
                local podRadius = module.podRadius or (radius * 0.08)
                local offset = module.angleOffset or 0
                local rotationOffset = module.rotationOffset or 0
                for i = 1, count do
                    local angle = offset + (i - 1) * ((2 * math.pi) / count)
                    local px = math.cos(angle) * radius
                    local py = math.sin(angle) * radius
                    add({ type = "polygon", x = px, y = py, rot = angle + rotationOffset, color = module.color or {0.7,0.85,1,0.5}, vertices = regularPolygon(sides, podRadius), spinSpeed = module.spinSpeed })
                    if module.glow then
                        add({ type = "glow", x = px, y = py, radius = module.glow.radius or (podRadius * 1.2), color = module.glow.color or module.color or {0.7,0.85,1,0.25} })
                    end
                end
            elseif moduleType == "lights" or moduleType == "beacons" then
                local count = module.count or 10
                local radius = module.radius or (hullRadius + 20)
                local size = module.size or 6
                local offset = module.angleOffset or 0
                for i = 1, count do
                    local angle = offset + (i - 1) * ((2 * math.pi) / count)
                    add({ type = "glow", x = math.cos(angle) * radius, y = math.sin(angle) * radius, radius = size, color = module.color or {1,1,1,0.35} })
                end
            elseif moduleType == "dish" or moduleType == "radar" then
                add({ type = "arc", radius = module.radius or (hullRadius * 0.6), startAngle = module.startAngle or -0.4, endAngle = module.endAngle or 0.4, width = module.width or 3, color = module.color or {0.9,0.95,1,0.55}, spinSpeed = module.spinSpeed or 0.6 })
                add({ type = "rect", width = (module.mastLength or 22), height = (module.mastWidth or 6), rot = module.mastAngle or 0, color = module.mastColor or module.color or {0.75,0.8,0.95,0.6} })
                if module.capRadius then add({ type = "circle", radius = module.capRadius, color = module.capColor or module.color or {0.9,0.95,1,0.5} }) end
            elseif moduleType == "antenna" then
                add({ type = "line", rot = module.angle or 0, x1 = 0, y1 = 0, x2 = module.length or (hullRadius * 0.75), y2 = 0, width = module.width or 2, color = module.color or {0.9,0.95,1,0.7}, spinSpeed = module.spinSpeed })
            elseif moduleType == "shield" then
                add({ type = "glow", radius = module.radius or (hullRadius * 1.3), color = module.color or {0.5,0.7,1,0.2} })
            elseif moduleType == "core_glow" then
                add({ type = "glow", radius = module.radius or (hullRadius * 0.35), color = module.color or {1,1,1,0.3} })
            end
        end
    end

    -- Legacy/alternate fields
    if detailDef.core then add({ type = "circle", radius = detailDef.core.radius or (hullRadius * 0.28), color = detailDef.core.color or {1,1,1,0.25} }) end
    return parts
end

function StationPrefab.generate(spawnData)
    spawnData = spawnData or {}
    local designName = spawnData.design
    local design = StationDesigns.getDesign(designName)

    -- Merge spawnData with design defaults (spawnData takes precedence)
    local merged = {}
    for k, v in pairs(design or {}) do merged[k] = v end
    for k, v in pairs(spawnData or {}) do merged[k] = v end

    local x = merged.x or 0
    local y = merged.y or 0
    local size = merged.size or 100
    local mass = merged.mass or 1200
    local color = merged.color or {0.8, 0.8, 0.95, 1}
    local label = merged.label

    local hullSides = merged.hullSides or 8
    local hullRadius = merged.hullRadius or size
    local verts = regularPolygon(hullSides, hullRadius)
    local inertia = Components.calculatePolygonInertia(verts, mass)

    local stationDetails = buildStationDetails(hullRadius, merged)

    return {
        Position = Components.Position(x, y),
        Velocity = Components.Velocity(0, 0),
        Physics = Components.Physics(0.995, mass, 0.999),
        PolygonShape = Components.PolygonShape(verts, merged.hullRotation or 0),
        RotationalMass = Components.RotationalMass(inertia),
        Collidable = Components.Collidable(merged.collidableRadius or hullRadius),
        Renderable = Components.Renderable("polygon", nil, nil, nil, merged.hullColor or color),
        Station = Components.Station(),
        -- Station core defenses: large hull and shield values for stations
        Hull = Components.Hull(10000, 10000),
        Shield = Components.Shield(10000, 10000, 0, 0),
        StationDetails = stationDetails,
        -- Only show a StationLabel when explicitly requested via `showLabel` (defaults to hidden)
        StationLabel = (merged.showLabel and label) and {label} or nil,
        FloatingQuestionMark = merged.disableQuestionMark and nil or Components.FloatingQuestionMark(12, 1.5, {1, 1, 0.2, 0.9}),
    }
end

return StationPrefab


