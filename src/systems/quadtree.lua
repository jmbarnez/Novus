-- Quadtree Spatial Partitioning
-- Optimizes collision detection by dividing space into quadrants
-- USE THIS if you have 50+ physics entities and experience lag

local Quadtree = {}

-- Create a new quadtree node
function Quadtree.create(x, y, width, height, depth)
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        depth = depth or 0,
        entities = {},
        children = nil,
        maxEntitiesPerNode = 4,
        maxDepth = 6
    }
end

-- Insert entity into quadtree
function Quadtree.insert(node, entityId, pos, radius)
    if node.children then
        -- Distribute to children
        local child = Quadtree.getChild(node, pos.x, pos.y)
        if child then
            return Quadtree.insert(child, entityId, pos, radius)
        end
    end
    
    table.insert(node.entities, {id = entityId, x = pos.x, y = pos.y, radius = radius})
    
    -- Subdivide if necessary
    if #node.entities > node.maxEntitiesPerNode and node.depth < node.maxDepth then
        Quadtree.subdivide(node)
    end
    
    return true
end

-- Subdivide node into 4 children
function Quadtree.subdivide(node)
    if node.children then return end
    
    local halfW = node.width / 2
    local halfH = node.height / 2
    local x = node.x
    local y = node.y
    
    node.children = {
        Quadtree.create(x, y, halfW, halfH, node.depth + 1),                    -- TL
        Quadtree.create(x + halfW, y, halfW, halfH, node.depth + 1),            -- TR
        Quadtree.create(x, y + halfH, halfW, halfH, node.depth + 1),            -- BL
        Quadtree.create(x + halfW, y + halfH, halfW, halfH, node.depth + 1)     -- BR
    }
    
    -- Redistribute entities
    local oldEntities = node.entities
    node.entities = {}
    for _, entity in ipairs(oldEntities) do
        local child = Quadtree.getChild(node, entity.x, entity.y)
        if child then
            table.insert(child.entities, entity)
        else
            table.insert(node.entities, entity)
        end
    end
end

-- Get appropriate child for position
function Quadtree.getChild(node, x, y)
    if not node.children then return nil end
    
    local midX = node.x + node.width / 2
    local midY = node.y + node.height / 2
    
    if x < midX then
        if y < midY then return node.children[1] else return node.children[3] end
    else
        if y < midY then return node.children[2] else return node.children[4] end
    end
end

-- Get all entities in range (for collision checks)
function Quadtree.getNearby(node, x, y, radius, result)
    result = result or {}
    
    -- Check bounding box intersection
    if not Quadtree.boundingBoxIntersects(node, x, y, radius) then
        return result
    end
    
    -- Add local entities
    for _, entity in ipairs(node.entities) do
        table.insert(result, entity)
    end
    
    -- Recurse into children
    if node.children then
        for _, child in ipairs(node.children) do
            Quadtree.getNearby(child, x, y, radius, result)
        end
    end
    
    return result
end

-- Check if bounding box intersects with query circle
function Quadtree.boundingBoxIntersects(node, cx, cy, radius)
    local closestX = math.max(node.x, math.min(cx, node.x + node.width))
    local closestY = math.max(node.y, math.min(cy, node.y + node.height))
    
    local dx = cx - closestX
    local dy = cy - closestY
    
    return (dx * dx + dy * dy) < (radius * radius)
end

-- Clear quadtree
function Quadtree.clear(node)
    node.entities = {}
    node.children = nil
end

return Quadtree
