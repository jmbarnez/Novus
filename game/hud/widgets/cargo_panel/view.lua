--- Cargo Panel View/Layout utilities
local M = {}

local Theme = require("game.theme")

--- Compute panel layout and slot rectangles
---@param ctx table HUD context
---@param windowFrame table WindowFrame instance
---@param self table Panel state (for frame position)
---@return table bounds Panel bounds with all layout info
---@return table slotRects Array of slot rectangles
function M.computeLayout(ctx, windowFrame, frameX, frameY)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local cp = hudTheme.cargoPanel or {}

    local margin = (ctx.layout and ctx.layout.margin) or hudTheme.layout.margin

    local pad = cp.pad or 6
    local headerH = cp.headerH or 24
    local footerH = cp.footerH or 26
    local slot = cp.slot or 44
    local gap = cp.gap or 6
    local footerGap = cp.footerGap or (cp.barGap or 6)

    local cols = 4
    local rows = 4

    local gridW = cols * slot + (cols - 1) * gap
    local gridH = rows * slot + (rows - 1) * gap

    local panelW = pad * 2 + gridW
    local panelH = pad * 2 + headerH + gridH + footerGap + footerH

    -- Determine frame position
    local fx, fy = frameX, frameY
    if fx == nil or fy == nil then
        local screenW = ctx and ctx.screenW or 0
        local screenH = ctx and ctx.screenH or 0
        fx = math.floor((screenW - panelW) * 0.5)
        fy = math.floor((screenH - panelH) * 0.5)
    end

    local frameBounds = windowFrame:compute(ctx, panelW, panelH, {
        margin = margin,
        headerH = headerH,
        footerH = footerH,
        closeSize = cp.closeSize or 18,
        closePad = cp.closePad or 6,
    })

    local bounds = frameBounds
    bounds.pad = pad
    bounds.slot = slot
    bounds.gap = gap
    bounds.footerGap = footerGap
    bounds.gridX = frameBounds.x + pad
    bounds.gridY = frameBounds.y + pad + headerH
    bounds.gridW = gridW
    bounds.gridH = gridH
    bounds.cols = cols
    bounds.rows = rows

    -- Build slot rectangles
    local slotRects = {}
    local gridX = frameBounds.x + pad
    local gridY = frameBounds.y + pad + headerH
    local idx = 1
    for r = 1, rows do
        for c = 1, cols do
            local sx = gridX + (c - 1) * (slot + gap)
            local sy = gridY + (r - 1) * (slot + gap)
            local slotIdx = (r - 1) * cols + c
            slotRects[idx] = { x = sx, y = sy, w = slot, h = slot, idx = slotIdx }
            idx = idx + 1
        end
    end

    return bounds, slotRects, fx, fy
end

--- Get player ship from world
---@param world table ECS world
---@return table|nil Ship entity
function M.getPlayerShip(world)
    local player = world and world:getResource("player")
    if player and player.pilot and player.pilot.ship then
        return player.pilot.ship
    end
    return nil
end

--- Pick slot at mouse position
---@param slotRects table Array of slot rectangles
---@param mx number Mouse X
---@param my number Mouse Y
---@param isOpen boolean Whether panel is open
---@return number|nil Slot index or nil
function M.pickSlot(slotRects, mx, my, isOpen)
    if not isOpen then
        return nil
    end

    local Rect = require("util.rect")
    for i = 1, #slotRects do
        local r = slotRects[i]
        if r and Rect.pointInRect(mx, my, r) then
            return r.idx
        end
    end

    return nil
end

return M
