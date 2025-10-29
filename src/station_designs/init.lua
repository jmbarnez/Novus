-- Station designs registry
local designs = {}

-- Quest kiosk design: gray/white/black/blue color scheme, built-in structure
designs.quest_kiosk = {
    hullSides = 12,
    hullRadius = 110,
    hullRotation = 0,
    hullColor = {0.45, 0.45, 0.5, 1}, -- medium gray base
    collidableRadius = 120,
    disableQuestionMark = true,
    modules = {
        -- Core center (white highlight)
        { type = "disc", radius = 32, color = {0.95, 0.95, 0.98, 1} },
        
        -- Inner structural ring (dark gray/black)
        { type = "ring", radius = 70, width = 8, color = {0.2, 0.2, 0.25, 1} },
        
        -- Structural spokes (medium gray) - stay within hull
        { type = "spokes", count = 8, innerRadius = 35, outerRadius = 105, width = 8, color = {0.6, 0.6, 0.65, 1} },
        
        -- Outer panels (blue tech accents) - moved inward to stay within hull
        { type = "panels", count = 6, radius = 100, width = 50, height = 14, color = {0.3, 0.5, 0.7, 0.85} },
        
        -- Status lights (blue/white) - along the edge but within hull
        { type = "lights", count = 12, radius = 105, size = 4, color = {0.5, 0.7, 0.95, 1} }
    }
}

local StationDesigns = {}

function StationDesigns.getDesign(name)
    if not name then return nil end
    return designs[name]
end

function StationDesigns.listDesigns()
    local out = {}
    for k, _ in pairs(designs) do table.insert(out, k) end
    return out
end

return StationDesigns


