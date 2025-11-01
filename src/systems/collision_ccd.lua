local CollisionUtils = require('src.collision_utils')
local math_sqrt = math.sqrt

local M = {}

-- Swept circle-circle CCD
function M.checkSweptCircleCircle(oldPos, newPos, radius1, staticPos, radius2)
    local minDist = radius1 + radius2
    local dx = newPos.x - oldPos.x
    local dy = newPos.y - oldPos.y
    local fx = oldPos.x - staticPos.x
    local fy = oldPos.y - staticPos.y
    local a = dx * dx + dy * dy
    local b = 2 * (fx * dx + fy * dy)
    local c = (fx * fx + fy * fy) - (minDist * minDist)
    if a < 0.0001 then
        local dist = math_sqrt(fx * fx + fy * fy)
        return dist < minDist, 0
    end
    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then
        return false, 1
    end
    discriminant = math_sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)
    if t1 >= 0 and t1 <= 1 then
        return true, t1
    elseif t2 >= 0 and t2 <= 1 then
        return true, t2
    elseif t1 < 0 and t2 > 1 then
        return true, 0
    end
    return false, 1
end

-- Swept circle-polygon CCD
function M.checkSweptCirclePolygon(oldPos, newPos, radius, polygonPos, polygonShape)
    local polygonWorld = CollisionUtils.transformPolygon(polygonPos, polygonShape)
    if CollisionUtils.checkPolygonCircleCollision(polygonWorld, newPos.x, newPos.y, radius) then
        return true, newPos
    end
    if CollisionUtils.checkPolygonCircleCollision(polygonWorld, oldPos.x, oldPos.y, radius) then
        return true, oldPos
    end

    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    local transformedVertices = {}
    for i = 1, #vertices do
        local v = vertices[i]
        local rx = v.x * cos - v.y * sin
        local ry = v.x * sin + v.y * cos
        transformedVertices[i] = {x = polygonPos.x + rx, y = polygonPos.y + ry}
    end

    local sweepRadius = radius
    local closestImpact = nil
    local closestDist = math.huge
    for i = 1, #transformedVertices do
        local v1 = transformedVertices[i]
        local v2 = transformedVertices[(i % #transformedVertices) + 1]
        local edgeDx = v2.x - v1.x
        local edgeDy = v2.y - v1.y
        local edgeLen = math_sqrt(edgeDx * edgeDx + edgeDy * edgeDy)
        if edgeLen > 0 then
            local sweepDx = newPos.x - oldPos.x
            local sweepDy = newPos.y - oldPos.y
            local f1x = oldPos.x - v1.x
            local f1y = oldPos.y - v1.y
            local sweepDot = sweepDx * sweepDx + sweepDy * sweepDy
            if sweepDot > 0.0001 then
                local t = -(f1x * sweepDx + f1y * sweepDy) / sweepDot
                t = math.max(0, math.min(1, t))
                local px = oldPos.x + t * sweepDx
                local py = oldPos.y + t * sweepDy
                local edgeDot2 = (px - v1.x) * edgeDx + (py - v1.y) * edgeDy
                local s = edgeDot2 / (edgeLen * edgeLen)
                s = math.max(0, math.min(1, s))
                local ex = v1.x + s * edgeDx
                local ey = v1.y + s * edgeDy
                local dx = px - ex
                local dy = py - ey
                local dist = math_sqrt(dx * dx + dy * dy)
                if dist < sweepRadius and dist < closestDist then
                    closestDist = dist
                    closestImpact = {x = px, y = py}
                end
            end
        end
    end
    if closestImpact then
        return true, closestImpact
    end
    return false
end

return M


