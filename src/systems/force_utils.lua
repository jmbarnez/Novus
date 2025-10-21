-- Force Utilities
-- Helper functions for applying forces to entities

local ECS = require('src.ecs')

local ForceUtils = {}

-- Apply a force to an entity at a specific point
-- This will create both linear and angular effects (torque)
-- @param entityId number: Entity to apply force to
-- @param forceX number: X component of force
-- @param forceY number: Y component of force
-- @param pointX number: X coordinate where force is applied (world space)
-- @param pointY number: Y coordinate where force is applied (world space)
function ForceUtils.applyForceAtPoint(entityId, forceX, forceY, pointX, pointY)
    local force = ECS.getComponent(entityId, "Force")
    local position = ECS.getComponent(entityId, "Position")
    
    if not force then
        -- Entity doesn't have Force component, skip
        return
    end
    
    -- Add linear force
    force.fx = force.fx + forceX
    force.fy = force.fy + forceY
    
    -- Calculate torque if we have position information
    if position and pointX and pointY then
        -- Vector from entity center to application point
        local rx = pointX - position.x
        local ry = pointY - position.y
        
        -- Torque = r × F (cross product in 2D: rx * Fy - ry * Fx)
        local torque = rx * forceY - ry * forceX
        force.torque = force.torque + torque
    end
end

-- Apply a force at the entity's center (no torque)
-- @param entityId number: Entity to apply force to
-- @param forceX number: X component of force
-- @param forceY number: Y component of force
function ForceUtils.applyForce(entityId, forceX, forceY)
    local force = ECS.getComponent(entityId, "Force")
    if force then
        force.fx = force.fx + forceX
        force.fy = force.fy + forceY
    end
end

-- Apply torque directly (rotational force)
-- @param entityId number: Entity to apply torque to
-- @param torque number: Torque to apply (positive = counter-clockwise)
function ForceUtils.applyTorque(entityId, torque)
    local force = ECS.getComponent(entityId, "Force")
    if force then
        force.torque = force.torque + torque
    end
end

-- Apply an impulse (instant velocity change, not force-based)
-- Useful for explosions, collisions, etc.
-- @param entityId number: Entity to apply impulse to
-- @param impulseX number: X component of impulse
-- @param impulseY number: Y component of impulse
function ForceUtils.applyImpulse(entityId, impulseX, impulseY)
    local velocity = ECS.getComponent(entityId, "Velocity")
    local physics = ECS.getComponent(entityId, "Physics")
    
    if velocity and physics then
        -- Impulse changes velocity directly: Δv = impulse / mass
        velocity.vx = velocity.vx + impulseX / physics.mass
        velocity.vy = velocity.vy + impulseY / physics.mass
    end
end

-- Apply angular impulse (instant angular velocity change)
-- @param entityId number: Entity to apply angular impulse to
-- @param angularImpulse number: Angular impulse to apply
function ForceUtils.applyAngularImpulse(entityId, angularImpulse)
    local angularVel = ECS.getComponent(entityId, "AngularVelocity")
    local rotMass = ECS.getComponent(entityId, "RotationalMass")
    
    if angularVel and rotMass then
        -- Angular impulse changes angular velocity: Δω = L / I
        angularVel.omega = angularVel.omega + angularImpulse / rotMass.inertia
    end
end

-- Apply a constant acceleration force (like gravity or thrust)
-- This is added every frame, so use carefully
-- @param entityId number: Entity to apply force to
-- @param accelerationX number: X component of acceleration
-- @param accelerationY number: Y component of acceleration
function ForceUtils.applyConstantAcceleration(entityId, accelerationX, accelerationY)
    local force = ECS.getComponent(entityId, "Force")
    local physics = ECS.getComponent(entityId, "Physics")
    
    if force and physics then
        -- F = ma
        force.fx = force.fx + accelerationX * physics.mass
        force.fy = force.fy + accelerationY * physics.mass
    end
end

return ForceUtils
