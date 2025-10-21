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

-- Physics component - Physics properties
-- @field friction number: Air/space resistance (0-1)
-- @field mass number: Mass for physics calculations
Components.Physics = function(friction, mass)
    return {
        friction = friction or Constants.player_friction,
        mass = mass or 1
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

return Components
