--- Fullscreen Map View calculations and coordinate utilities
local M = {}

local Theme = require("game.theme")
local MathUtil = require("util.math")

--- Clamp the center position to keep view within sector bounds
---@param sector table Sector with width/height
---@param centerX number Center X position
---@param centerY number Center Y position
---@param viewW number View width
---@param viewH number View height
---@return number, number Clamped centerX, centerY
function M.clampCenter(sector, centerX, centerY, viewW, viewH)
    local originX = (sector and sector.originX) or 0
    local originY = (sector and sector.originY) or 0
    if not sector then
        return centerX, centerY
    end

    local halfW = viewW * 0.5
    local halfH = viewH * 0.5

    if viewW >= sector.width then
        centerX = originX + sector.width * 0.5
    else
        centerX = MathUtil.clamp(centerX, originX + halfW, originX + sector.width - halfW)
    end

    if viewH >= sector.height then
        centerY = originY + sector.height * 0.5
    else
        centerY = MathUtil.clamp(centerY, originY + halfH, originY + sector.height - halfH)
    end

    return centerX, centerY
end

--- Compute window and map layout rectangles
---@param ctx table HUD context
---@param windowFrame table WindowFrame instance
---@return table, table, table, table mapRect, legendRect, windowRect, frameBounds
function M.computeLayout(ctx, windowFrame)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local fm = hudTheme.fullscreenMap or {}

    local screenW = ctx and ctx.screenW or 0
    local screenH = ctx and ctx.screenH or 0

    local margin = (hudTheme.layout and hudTheme.layout.margin) or 16
    local gap = (hudTheme.layout and hudTheme.layout.stackGap) or 18

    local maxW = screenW - margin * 2
    local maxH = screenH - margin * 2
    local desiredW = math.min(maxW, math.floor((fm.windowWFactor or 0.85) * screenW))
    local desiredH = math.min(maxH, math.floor((fm.windowHFactor or 0.82) * screenH))

    local headerH = fm.headerH or 32
    local bounds = windowFrame:compute(ctx, desiredW, desiredH, {
        headerH = headerH,
        footerH = 0,
        closeSize = fm.closeSize or 18,
        closePad = fm.closePad or 10,
        margin = margin,
    })

    local windowRect = {
        x = bounds.x,
        y = bounds.y,
        w = bounds.w,
        h = bounds.h,
    }

    local pad = fm.windowPadding or 18
    local legendW = fm.legendW or 260

    local headerOffset = bounds.headerRect and bounds.headerRect.h or 0
    local mapRect = {
        x = windowRect.x + pad,
        y = windowRect.y + headerOffset + pad,
        w = windowRect.w - pad * 2 - legendW - gap,
        h = windowRect.h - headerOffset - pad * 2,
    }

    local minMapW = fm.minMapW or 200
    if mapRect.w < minMapW then
        mapRect.w = windowRect.w - pad * 2
        legendW = 0
    end

    local legendRect
    if legendW > 0 then
        legendRect = {
            x = mapRect.x + mapRect.w + gap,
            y = mapRect.y,
            w = legendW,
            h = mapRect.h,
        }
    end

    return mapRect, legendRect, windowRect, bounds
end

--- Compute view transform (scale, visible region)
---@param ctx table HUD context
---@param mapRect table Map rectangle
---@param mapUi table Map UI state (zoom, center)
---@return table|nil View data or nil if invalid
function M.computeView(ctx, mapRect, mapUi)
    local sector = ctx and ctx.sector

    if not mapUi or not sector or sector.width <= 0 or sector.height <= 0 then
        return nil
    end

    local zoom = mapUi.zoom or 1.0
    zoom = MathUtil.clamp(zoom, 1.0, 20.0)
    mapUi.zoom = zoom

    local viewW = sector.width / zoom
    local viewH = sector.height / zoom

    local scale = math.min(mapRect.w / viewW, mapRect.h / viewH)
    local drawW = viewW * scale
    local drawH = viewH * scale

    local drawRect = {
        x = mapRect.x + (mapRect.w - drawW) * 0.5,
        y = mapRect.y + (mapRect.h - drawH) * 0.5,
        w = drawW,
        h = drawH,
        scale = scale,
        viewW = viewW,
        viewH = viewH,
    }

    mapUi.centerX = mapUi.centerX or (ctx.x or (sector.width * 0.5))
    mapUi.centerY = mapUi.centerY or (ctx.y or (sector.height * 0.5))

    local originX = sector.originX or 0
    local originY = sector.originY or 0
    if mapUi.centerX == sector.width * 0.5 then
        mapUi.centerX = originX + sector.width * 0.5
    end
    if mapUi.centerY == sector.height * 0.5 then
        mapUi.centerY = originY + sector.height * 0.5
    end

    mapUi.centerX, mapUi.centerY = M.clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)

    local left = mapUi.centerX - viewW * 0.5
    local top = mapUi.centerY - viewH * 0.5

    return {
        mapUi = mapUi,
        sector = sector,
        drawRect = drawRect,
        left = left,
        top = top,
        scale = scale,
        viewW = viewW,
        viewH = viewH,
        zoom = zoom,
    }
end

--- Convert world coordinates to screen coordinates
---@param view table View data from computeView
---@param wx number World X
---@param wy number World Y
---@return number, number Screen X, Y
function M.worldToScreen(view, wx, wy)
    local dr = view.drawRect
    local sx = dr.x + (wx - view.left) * view.scale
    local sy = dr.y + (wy - view.top) * view.scale
    return sx, sy
end

--- Convert screen coordinates to world coordinates
---@param view table View data from computeView
---@param sx number Screen X
---@param sy number Screen Y
---@return number, number World X, Y
function M.screenToWorld(view, sx, sy)
    local dr = view.drawRect
    local wx = view.left + ((sx - dr.x) / view.scale)
    local wy = view.top + ((sy - dr.y) / view.scale)
    return wx, wy
end

--- Calculate nice step value for grid lines
---@param raw number Raw step value
---@return number Rounded step value
function M.niceStep(raw)
    if raw <= 0 then
        return 1
    end

    local p = 10 ^ math.floor(math.log(raw) / math.log(10))
    local n = raw / p

    if n <= 1 then
        return 1 * p
    elseif n <= 2 then
        return 2 * p
    elseif n <= 5 then
        return 5 * p
    end

    return 10 * p
end

--- Get the legend button rectangle
---@param legendRect table Legend rectangle
---@return table|nil Button rectangle or nil
function M.legendButtonRect(legendRect)
    if not legendRect then
        return nil
    end

    return {
        x = legendRect.x + 12,
        y = legendRect.y + legendRect.h - 44,
        w = legendRect.w - 24,
        h = 30,
    }
end

return M
