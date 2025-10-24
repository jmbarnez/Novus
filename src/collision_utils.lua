-- src/collision_utils.lua
-- Utility module for shared collision detection functions
-- Used by both collision.lua and physics_collision.lua

local CollisionUtils = {}

-- Check if two circles overlap
function CollisionUtils.checkBoundingCircles(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distSq = dx * dx + dy * dy
    local radiusSum = r1 + r2
    return distSq <= radiusSum * radiusSum
end

-- Check if a point is inside a polygon
function CollisionUtils.pointInPolygon(px, py, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- Distance from a point to a line segment
function CollisionUtils.pointToLineSegmentDistance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    if dx == 0 and dy == 0 then
        dx = px - x1
        dy = py - y1
        return math.sqrt(dx * dx + dy * dy)
    end
    local t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
    t = math.max(0, math.min(1, t))
    local lx = x1 + t * dx
    local ly = y1 + t * dy
    dx = px - lx
    dy = py - ly
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if a polygon and a circle collide
function CollisionUtils.checkPolygonCircleCollision(polygon, cx, cy, cr)
    if CollisionUtils.pointInPolygon(cx, cy, polygon) then
        return true
    end
    for i = 1, #polygon do
        local j = (i % #polygon) + 1
        local x1, y1 = polygon[i][1], polygon[i][2]
        local x2, y2 = polygon[j][1], polygon[j][2]
        if CollisionUtils.pointToLineSegmentDistance(cx, cy, x1, y1, x2, y2) <= cr then
            return true
        end
    end
    return false
end

-- Check if two polygons collide
function CollisionUtils.checkPolygonPolygonCollision(polyA, polyB)
    local function polygonsOverlap(a, b)
        for i = 1, #a do
            local j = (i % #a) + 1
            local ax, ay = a[i][1], a[i][2]
            local bx, by = a[j][1], a[j][2]
            local nx, ny = ay - by, bx - ax
            local minA, maxA = nil, nil
            for k = 1, #a do
                local proj = nx * a[k][1] + ny * a[k][2]
                minA = minA and math.min(minA, proj) or proj
                maxA = maxA and math.max(maxA, proj) or proj
            end
            local minB, maxB = nil, nil
            for k = 1, #b do
                local proj = nx * b[k][1] + ny * b[k][2]
                minB = minB and math.min(minB, proj) or proj
                maxB = maxB and math.max(maxB, proj) or proj
            end
            if maxA < minB or maxB < minA then
                return false
            end
        end
        return true
    end
    return polygonsOverlap(polyA, polyB) and polygonsOverlap(polyB, polyA)
end

-- Transform polygon vertices from local space to world space
-- @param pos table: Position component with x, y coordinates
-- @param shape table: PolygonShape component with vertices and rotation
-- @return table: Array of transformed vertices in world space (format: {{x, y}, {x, y}, ...})
function CollisionUtils.transformPolygon(pos, shape)
    local worldPoly = {}
    local cos = math.cos(shape.rotation)
    local sin = math.sin(shape.rotation)
    for _, v in ipairs(shape.vertices) do
        local rx = v.x * cos - v.y * sin
        local ry = v.x * sin + v.y * cos
        table.insert(worldPoly, {pos.x + rx, pos.y + ry})
    end
    return worldPoly
end

return CollisionUtils
