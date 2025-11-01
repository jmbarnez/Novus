local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin

local M = {}

local function getTransformedVertices(pos, vertices, rotation)
    local transformed = {}
    local cos = math_cos(rotation)
    local sin = math_sin(rotation)
    for i = 1, #vertices do
        local v = vertices[i]
        local rx = v.x * cos - v.y * sin
        local ry = v.x * sin + v.y * cos
        transformed[i] = {x = pos.x + rx, y = pos.y + ry}
    end
    return transformed
end

local function getAxes(vertices)
    local axes = {}
    for i = 1, #vertices do
        local p1 = vertices[i]
        local p2 = vertices[(i % #vertices) + 1]
        local edgeX = p2.x - p1.x
        local edgeY = p2.y - p1.y
        local normalX = -edgeY
        local normalY = edgeX
        local length = math_sqrt(normalX * normalX + normalY * normalY)
        if length > 0 then
            axes[#axes + 1] = {x = normalX / length, y = normalY / length}
        end
    end
    return axes
end

local function project(axis, vertices)
    local minProjection = (vertices[1].x * axis.x) + (vertices[1].y * axis.y)
    local maxProjection = minProjection
    for i = 2, #vertices do
        local projection = (vertices[i].x * axis.x) + (vertices[i].y * axis.y)
        minProjection = math_min(minProjection, projection)
        maxProjection = math_max(maxProjection, projection)
    end
    return minProjection, maxProjection
end

function M.checkPolygonPolygonCollisionSAT(polygon1Pos, polygon1Shape, polygon2Pos, polygon2Shape)
    local transformedVertices1 = getTransformedVertices(polygon1Pos, polygon1Shape.vertices, polygon1Shape.rotation)
    local transformedVertices2 = getTransformedVertices(polygon2Pos, polygon2Shape.vertices, polygon2Shape.rotation)

    local axes = getAxes(transformedVertices1)
    for _, axis in ipairs(getAxes(transformedVertices2)) do
        table.insert(axes, axis)
    end

    local minOverlap = nil
    local smallestAxis = nil

    for _, axis in ipairs(axes) do
        local min1, max1 = project(axis, transformedVertices1)
        local min2, max2 = project(axis, transformedVertices2)

        local overlap = math_min(max1, max2) - math_max(min1, min2)

        if overlap < 0 then
            return false, nil, nil
        end

        if minOverlap == nil or overlap < minOverlap then
            minOverlap = overlap
            smallestAxis = axis
        end
    end

    if smallestAxis then
        local direction = {x = polygon2Pos.x - polygon1Pos.x, y = polygon2Pos.y - polygon1Pos.y}
        if (direction.x * smallestAxis.x + direction.y * smallestAxis.y) < 0 then
            smallestAxis.x = -smallestAxis.x
            smallestAxis.y = -smallestAxis.y
        end
        return true, smallestAxis, minOverlap
    end

    return false, nil, nil
end

function M.findCollisionNormal(polygonPos, polygonShape, circlePos, circleRadius)
    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation
    local transformedVertices = getTransformedVertices(polygonPos, vertices, rotation)

    local closestDist = math.huge
    local closestPoint = {x = polygonPos.x, y = polygonPos.y}
    local closestNormal = {x = 0, y = 1}

    for i = 1, #transformedVertices do
        local v1 = transformedVertices[i]
        local v2 = transformedVertices[(i % #transformedVertices) + 1]
        local A = circlePos.x - v1.x
        local B = circlePos.y - v1.y
        local C = v2.x - v1.x
        local D = v2.y - v1.y
        local dot = A * C + B * D
        local lenSq = C * C + D * D
        local param = 0
        if lenSq > 0 then
            param = math_max(0, math_min(1, dot / lenSq))
        end
        local px = v1.x + param * C
        local py = v1.y + param * D
        local dx = circlePos.x - px
        local dy = circlePos.y - py
        local dist = math_sqrt(dx * dx + dy * dy)
        if dist < closestDist then
            closestDist = dist
            closestPoint = {x = px, y = py}
            local edgeLen = math_sqrt(C * C + D * D)
            if edgeLen > 0 then
                local edgeNx = -D / edgeLen
                local edgeNy = C / edgeLen
                if edgeNx * dx + edgeNy * dy < 0 then
                    edgeNx = -edgeNx
                    edgeNy = -edgeNy
                end
                closestNormal = {x = edgeNx, y = edgeNy}
            end
        end
    end

    return {normal = closestNormal, distance = closestDist, point = closestPoint}
end

return M


