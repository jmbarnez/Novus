local M = {}

--- Check if a point (px, py) is inside a rectangle r = { x, y, w, h }
---@param px number Point X coordinate
---@param py number Point Y coordinate
---@param r table Rectangle with x, y, w, h fields
---@return boolean
function M.pointInRect(px, py, r)
    return px >= r.x and px <= (r.x + r.w) and py >= r.y and py <= (r.y + r.h)
end

return M
