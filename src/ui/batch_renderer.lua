---@diagnostic disable: undefined-global
-- Batch Renderer - Minimizes draw calls and state changes for UI/HUD elements
-- Accumulates primitives and draws them in optimized batches

local BatchRenderer = {}

-- Batch storage
local rectBatches = {}      -- Grouped by color
local circleBatches = {}    -- Grouped by color and mode (fill/line)
local lineBatches = {}      -- Grouped by color and width
local textBatches = {}      -- Grouped by font
local polyBatches = {}      -- Grouped by color and mode

-- Temporary storage for current frame
local currentRects = {}
local currentCircles = {}
local currentLines = {}
local currentTexts = {}
local currentPolys = {}

-- Helper to create color key for batching
local function colorKey(r, g, b, a)
    return string.format("%.3f_%.3f_%.3f_%.3f", r or 1, g or 1, b or 1, a or 1)
end

-- Begin a new frame
function BatchRenderer.begin()
    -- Clear batch storage
    for k in pairs(currentRects) do currentRects[k] = nil end
    for k in pairs(currentCircles) do currentCircles[k] = nil end
    for k in pairs(currentLines) do currentLines[k] = nil end
    for k in pairs(currentTexts) do currentTexts[k] = nil end
    for k in pairs(currentPolys) do currentPolys[k] = nil end
end

-- Queue a filled rectangle
function BatchRenderer.queueRect(x, y, w, h, r, g, b, a, rounded)
    rounded = rounded or 0
    local key = colorKey(r, g, b, a)
    currentRects[key] = currentRects[key] or {}
    table.insert(currentRects[key], {x=x, y=y, w=w, h=h, rounded=rounded})
end

-- Queue a rectangle outline
function BatchRenderer.queueRectLine(x, y, w, h, r, g, b, a, lineWidth, rounded)
    lineWidth = lineWidth or 1
    rounded = rounded or 0
    local key = string.format("%s_w%.1f", colorKey(r, g, b, a), lineWidth)
    currentLines[key] = currentLines[key] or {width=lineWidth, rects={}}
    table.insert(currentLines[key].rects, {x=x, y=y, w=w, h=h, rounded=rounded})
end

-- Queue a filled circle
function BatchRenderer.queueCircle(x, y, radius, r, g, b, a)
    local key = colorKey(r, g, b, a)
    currentCircles[key] = currentCircles[key] or {fill={}, line={}}
    table.insert(currentCircles[key].fill, {x=x, y=y, radius=radius})
end

-- Queue a circle outline
function BatchRenderer.queueCircleLine(x, y, radius, r, g, b, a, lineWidth)
    lineWidth = lineWidth or 1
    local key = string.format("%s_w%.1f", colorKey(r, g, b, a), lineWidth)
    currentCircles[key] = currentCircles[key] or {fill={}, line={}}
    table.insert(currentCircles[key].line, {x=x, y=y, radius=radius, width=lineWidth})
end

-- Queue a polygon (filled)
function BatchRenderer.queuePolygon(vertices, r, g, b, a)
    local key = colorKey(r, g, b, a)
    currentPolys[key] = currentPolys[key] or {}
    table.insert(currentPolys[key], vertices)
end

-- Queue text
function BatchRenderer.queueText(text, x, y, font, r, g, b, a, align, width)
    local fontKey = tostring(font)
    currentTexts[fontKey] = currentTexts[fontKey] or {font=font, items={}}
    table.insert(currentTexts[fontKey].items, {
        text=text, x=x, y=y, 
        r=r or 1, g=g or 1, b=b or 1, a=a or 1,
        align=align, width=width
    })
end

-- Flush all batches to screen
function BatchRenderer.flush()
    -- Draw all filled rectangles (batched by color)
    for key, rects in pairs(currentRects) do
        local r, g, b, a = key:match("([^_]+)_([^_]+)_([^_]+)_([^_]+)")
        love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
        for _, rect in ipairs(rects) do
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, rect.rounded, rect.rounded)
        end
    end
    
    -- Draw all filled circles (batched by color)
    for key, circles in pairs(currentCircles) do
        if #circles.fill > 0 then
            local r, g, b, a = key:match("([^_]+)_([^_]+)_([^_]+)_([^_]+)")
            love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
            for _, circle in ipairs(circles.fill) do
                love.graphics.circle("fill", circle.x, circle.y, circle.radius)
            end
        end
    end
    
    -- Draw all polygons (batched by color)
    for key, polys in pairs(currentPolys) do
        local r, g, b, a = key:match("([^_]+)_([^_]+)_([^_]+)_([^_]+)")
        love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
        for _, vertices in ipairs(polys) do
            if #vertices >= 6 then  -- At least 3 points
                love.graphics.polygon("fill", vertices)
            end
        end
    end
    
    -- Draw all lines (rectangles and circles) batched by color and width
    for key, data in pairs(currentLines) do
        local colorWidth = key:match("([^_]+_[^_]+_[^_]+_[^_]+)_w")
        local r, g, b, a = colorWidth:match("([^_]+)_([^_]+)_([^_]+)_([^_]+)")
        love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
        love.graphics.setLineWidth(data.width)
        for _, rect in ipairs(data.rects) do
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, rect.rounded, rect.rounded)
        end
    end
    
    -- Draw circle outlines
    for key, circles in pairs(currentCircles) do
        if #circles.line > 0 then
            for _, circle in ipairs(circles.line) do
                local r, g, b, a = key:match("([^_]+)_([^_]+)_([^_]+)_([^_]+)")
                love.graphics.setColor(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
                love.graphics.setLineWidth(circle.width)
                love.graphics.circle("line", circle.x, circle.y, circle.radius)
            end
        end
    end
    
    -- Draw all text (batched by font)
    for fontKey, batch in pairs(currentTexts) do
        love.graphics.setFont(batch.font)
        for _, item in ipairs(batch.items) do
            love.graphics.setColor(item.r, item.g, item.b, item.a)
            if item.align and item.width then
                love.graphics.printf(item.text, item.x, item.y, item.width, item.align)
            else
                love.graphics.print(item.text, item.x, item.y)
            end
        end
    end
    
    -- Reset state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return BatchRenderer
