---@diagnostic disable: undefined-global
local Constants = require('src.constants')
local Components = {}

-- Position component - 2D coordinates in world space
-- @field x number: X coordinate
-- @field y number: Y coordinate
-- @field prevX number: Previous X coordinate (for CCD)
-- @field prevY number: Previous Y coordinate (for CCD)
Components.Position = function(x, y)
    return {
        x = x or 0,
        y = y or 0,
        prevX = x or 0,
        prevY = y or 0
    }
end

-- Velocity component - Movement vector
-- @field vx number: X velocity
-- @field vy number: Y velocity
Components.Velocity = function(vx, vy)
    return {
        vx = vx or 0,
        vy = vy or 0
    }
end

-- Acceleration component - Force application
-- @field ax number: X acceleration
-- @field ay number: Y acceleration
Components.Acceleration = function(ax, ay)
    return {
        ax = ax or 0,
        ay = ay or 0
    } -- Close the table definition properly
end

-- Force component - Accumulates forces during frame, converted to acceleration
-- @field fx number: X force accumulator
-- @field fy number: Y force accumulator
-- @field torque number: Rotational force accumulator (for future use)
Components.Force = function(fx, fy, torque)
    return {
        fx = fx or 0,
        fy = fy or 0,
        torque = torque or 0
    }
end

-- Physics component - Physics properties
-- @field friction number: Air/space resistance (0-1)
-- @field mass number: Mass for physics calculations (kg equivalent)
-- @field angularDamping number: Rotational resistance (0-1, closer to 1 = more damping)
-- @field restitution number: Coefficient of restitution (0-1, 1 = perfectly elastic)
Components.Physics = function(friction, mass, angularDamping, restitution)
    return {
        friction = friction or Constants.player_friction,
        mass = mass or 1,
        angularDamping = angularDamping or 0.98,  -- Default: slight rotational damping
        restitution = restitution or 0.2
    }
end

-- AngularVelocity component - Rotation speed
-- @field omega number: Rotation speed in radians per second
Components.AngularVelocity = function(omega)
    return {
        omega = omega or 0
    }
end

-- RotationalMass component - Moment of inertia for rotational physics
-- @field inertia number: Moment of inertia (resistance to rotation)
Components.RotationalMass = function(inertia)
    return {
        inertia = inertia or 1
    }
end

-- Helper: Calculate polygon area using shoelace formula
-- @param vertices table: Array of {x, y} vertices
-- @return number: Area of the polygon
Components.calculatePolygonArea = function(vertices)
    if not vertices or #vertices < 3 then
        return 0
    end
    
    local area = 0
    local numVertices = #vertices
    
    for i = 1, numVertices do
        local v1 = vertices[i]
        local v2 = vertices[(i % numVertices) + 1]
        area = area + (v1.x * v2.y - v2.x * v1.y)
    end
    
    return math.abs(area) * 0.5
end

-- Helper: Calculate moment of inertia for a polygon based on its shape and mass
-- Uses parallel axis theorem for accurate physics
-- @param vertices table: Array of {x, y} vertices (in local space, centered at origin)
-- @param mass number: Total mass of the object
-- @return number: Calculated moment of inertia
Components.calculatePolygonInertia = function(vertices, mass)
    if not vertices or #vertices < 3 then
        -- Fallback for invalid polygons - treat as circle with radius 10
        return mass * 10 * 10
    end
    
    -- Calculate centroid (should be close to origin for centered polygons)
    local cx, cy = 0, 0
    for _, v in ipairs(vertices) do
        cx = cx + v.x
        cy = cy + v.y
    end
    cx = cx / #vertices
    cy = cy / #vertices
    
    -- Calculate moment of inertia using polygon decomposition
    -- For each triangle from centroid to edge, sum their contributions
    local totalInertia = 0
    local numVertices = #vertices
    
    for i = 1, numVertices do
        local v1 = vertices[i]
        local v2 = vertices[(i % numVertices) + 1]
        
        -- Triangle vertices relative to centroid
        local x1 = v1.x - cx
        local y1 = v1.y - cy
        local x2 = v2.x - cx
        local y2 = v2.y - cy
        
        -- Area of this triangle (can be negative)
        local triangleArea = 0.5 * (x1 * y2 - x2 * y1)
        
        -- Moment of inertia for this triangle about the centroid
        -- I = (mass/area) * (1/6) * (x1^2 + x1*x2 + x2^2 + y1^2 + y1*y2 + y2^2)
        local triangleInertia = math.abs(triangleArea) * (x1*x1 + x1*x2 + x2*x2 + y1*y1 + y1*y2 + y2*y2) / 6
        
        totalInertia = totalInertia + triangleInertia
    end
    
    -- Scale by mass (assumes unit density, then multiply by actual mass)
    -- Add a minimum to prevent division by zero
    return math.max(totalInertia * mass * 0.1, mass * 0.5)
end

return Components
