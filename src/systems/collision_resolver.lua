local math_max = math.max

local M = {}

function M.resolveProjectileCollision(projectileId, otherId, normal, depth, ECS)
    -- Expect ECS to be passed in because resolver is used by system
    local projPos = ECS.getComponent(projectileId, "Position")
    local projVel = ECS.getComponent(projectileId, "Velocity")
    local projPhys = ECS.getComponent(projectileId, "Physics")
    local otherPos = ECS.getComponent(otherId, "Position")
    local otherVel = ECS.getComponent(otherId, "Velocity")
    local otherPhys = ECS.getComponent(otherId, "Physics")

    if not (projPos and projVel and projPhys and otherPos and otherVel and otherPhys) then return end

    local rvx = otherVel.vx - projVel.vx
    local rvy = otherVel.vy - projVel.vy
    local velAlongNormal = rvx * normal.x + rvy * normal.y
    if velAlongNormal >= 0 then return end

    local defaultRest = 0.2
    local e1 = projPhys.restitution or defaultRest
    local e2 = otherPhys.restitution or defaultRest
    local restitution = math_max(e1, e2)
    local j = -(1 + restitution) * velAlongNormal
    j = j / (1 / projPhys.mass + 1 / otherPhys.mass)

    local impulseX = j * normal.x
    local impulseY = j * normal.y

    projVel.vx = projVel.vx - (1 / projPhys.mass) * impulseX
    projVel.vy = projVel.vy - (1 / projPhys.mass) * impulseY
    otherVel.vx = otherVel.vx + (1 / otherPhys.mass) * impulseX
    otherVel.vy = otherVel.vy + (1 / otherPhys.mass) * impulseY

    local percent = 0.9
    local slop = 0.01
    local correction = math_max(depth - slop, 0) / (1 / projPhys.mass + 1 / otherPhys.mass) * percent
    projPos.x = projPos.x - (1 / projPhys.mass) * correction * normal.x
    projPos.y = projPos.y - (1 / projPhys.mass) * correction * normal.y
end

function M.resolveCollision(entity1, entity2, normal, depth)
    local pos1 = entity1.pos
    local vel1 = entity1.vel
    local phys1 = entity1.phys
    local angularVel1 = entity1.angularVel
    local rotMass1 = entity1.rotMass

    local pos2 = entity2.pos
    local vel2 = entity2.vel
    local phys2 = entity2.phys
    local angularVel2 = entity2.angularVel
    local rotMass2 = entity2.rotMass

    local rv = {x = vel2.vx - vel1.vx, y = vel2.vy - vel1.vy}
    local velAlongNormal = rv.x * normal.x + rv.y * normal.y
    if velAlongNormal >= 0 then return end

    local defaultRest = 0.2
    local e1 = phys1.restitution or defaultRest
    local e2 = phys2.restitution or defaultRest
    local restitution = math_max(e1, e2)
    local j = -(1 + restitution) * velAlongNormal
    j = j / (1 / phys1.mass + 1 / phys2.mass)

    local contactX = (pos1.x + pos2.x) / 2
    local contactY = (pos1.y + pos2.y) / 2

    local r1x = contactX - pos1.x
    local r1y = contactY - pos1.y
    local r2x = contactX - pos2.x
    local r2y = contactY - pos2.y

    local impulseX = j * normal.x
    local impulseY = j * normal.y

    local torque1 = r1x * impulseY - r1y * impulseX
    local torque2 = r2x * impulseY - r2y * impulseX

    vel1.vx = vel1.vx - (1 / phys1.mass) * impulseX
    vel1.vy = vel1.vy - (1 / phys1.mass) * impulseY
    vel2.vx = vel2.vx + (1 / phys2.mass) * impulseX
    vel2.vy = vel2.vy + (1 / phys2.mass) * impulseY

    if angularVel1 and rotMass1 then
        angularVel1.omega = angularVel1.omega - torque1 / rotMass1.inertia
    end
    if angularVel2 and rotMass2 then
        angularVel2.omega = angularVel2.omega + torque2 / rotMass2.inertia
    end

    local percent = 0.8
    local slop = 0.01
    local correction = math_max(depth - slop, 0) / (1 / phys1.mass + 1 / phys2.mass) * percent

    pos1.x = pos1.x - (1 / phys1.mass) * correction * normal.x
    pos1.y = pos1.y - (1 / phys1.mass) * correction * normal.y
    pos2.x = pos2.x + (1 / phys2.mass) * correction * normal.x
    pos2.y = pos2.y + (1 / phys2.mass) * correction * normal.y

    local rv_after = {x = vel2.vx - vel1.vx, y = vel2.vy - vel1.vy}
    local velAlongNormalAfter = rv_after.x * normal.x + rv_after.y * normal.y
    if velAlongNormalAfter < 0 then
        local damping = 0.5
        vel1.vx = vel1.vx + damping * velAlongNormalAfter * normal.x
        vel1.vy = vel1.vy + damping * velAlongNormalAfter * normal.y
        vel2.vx = vel2.vx - damping * velAlongNormalAfter * normal.x
        vel2.vy = vel2.vy - damping * velAlongNormalAfter * normal.y
    end
end

return M


