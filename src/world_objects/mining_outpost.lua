-- Mining Outpost - Industrial Station
-- Heavy-duty mining operations with ore processing capabilities

return {
    name = "Mining Outpost",
    description = "Industrial mining station specializing in ore extraction and processing",
    
    -- Basic properties
    x = 0,
    y = 0,
    size = 120,
    mass = 1500,
    color = {0.8, 0.75, 0.6, 1},
    label = "Mining Outpost",
    
    -- Hexagonal hull - industrial design
    hullSides = 6,
    hullRadius = 130,
    hullRotation = 0,
    hullColor = {0.7, 0.65, 0.5, 1},
    collidableRadius = 140,
    
    -- Industrial modules - simplified but functional
    modules = {
        -- Central reactor core
        { type = "core_glow", radius = 50, color = {1, 0.8, 0.4, 0.4} },
        
        -- Processing ring
        { type = "ring", radius = 65, width = 18, color = {0.6, 0.5, 0.3, 0.5} },
        
        -- Mining laser arrays (replacing spokes)
        { type = "spokes", count = 3, innerRadius = 35, outerRadius = 115, width = 12, color = {0.9, 0.7, 0.3, 0.6} },
        
        -- Heavy mining equipment pods
        { type = "pods", count = 6, radius = 165, sides = 4, podRadius = 20, rotationOffset = math.pi / 6, color = {0.6, 0.55, 0.4, 0.7} },
        
        -- Ore storage containers
        { type = "panels", count = 4, radius = 185, width = 80, height = 25, color = {0.4, 0.45, 0.3, 0.8} },
        
        -- Reinforced hull plating
        { type = "arms", count = 6, radius = 140, length = 45, width = 20, capRadius = 12, capOffset = 35, color = {0.5, 0.45, 0.35, 0.8} },
        
        -- Industrial lighting
        { type = "lights", count = 12, radius = 155, size = 8, color = {1, 0.9, 0.6, 0.5} },
        
        -- Mining scanner array
        { type = "dish", radius = 90, width = 6, startAngle = -0.6, endAngle = 0.6, spinSpeed = 0.8, mastLength = 35, mastWidth = 8, mastAngle = 0.12, color = {0.8, 0.7, 0.4, 0.7} },
        
        -- Heavy shield projector
        { type = "shield", radius = 210, color = {0.7, 0.6, 0.3, 0.25} }
    },
    
    disableQuestionMark = false
}