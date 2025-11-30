local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"
local DefaultSector = require "src.data.default_sector"

local MapPanel = {}

local function getWindowRect(world)
    local sw, sh = love.graphics.getDimensions()

    local defaultWidth = math.floor(sw * 0.75)
    local defaultHeight = math.floor(sh * 0.75)

    local ui = world and world.ui
    if ui and ui.map_window then
        local w = ui.map_window
        local x = w.x or (sw - (w.width or defaultWidth)) * 0.5
        local y = w.y or (sh - (w.height or defaultHeight)) * 0.5
        local width = w.width or defaultWidth
        local height = w.height or defaultHeight
        return x, y, width, height
    end

    local width = defaultWidth
    local height = defaultHeight
    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

local function drawBackgroundOverlay()
    local sw, sh = love.graphics.getDimensions()
    local dim = Theme.colors.overlay.screenDim
    love.graphics.setColor(dim[1], dim[2], dim[3], dim[4] or 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
end

local function worldToMap(content, ship, entity)
    local ship_sector = ship.sector or { x = 0, y = 0 }
    local sx = ship_sector.x or 0
    local sy = ship_sector.y or 0

    local t = entity.transform
    if not t then
        return nil, nil
    end

    local es = entity.sector or { x = sx, y = sy }
    local ex = es.x or 0
    local ey = es.y or 0

    local diff_sector_x = ex - sx
    local diff_sector_y = ey - sy

    local sector_size = DefaultSector.SECTOR_SIZE or 7500

    local world_diff_x = (t.x - ship.transform.x) + diff_sector_x * sector_size
    local world_diff_y = (t.y - ship.transform.y) + diff_sector_y * sector_size

    local half_extent = sector_size
    local nx = world_diff_x / half_extent
    local ny = world_diff_y / half_extent

    if nx <= -1 or nx >= 1 or ny <= -1 or ny >= 1 then
        return nil, nil
    end

    local cx, cy, cw, ch = content.x, content.y, content.w, content.h
    local px = cx + (nx * 0.5 + 0.5) * cw
    local py = cy + (ny * 0.5 + 0.5) * ch
    return px, py
end

function MapPanel.draw(world, player)
    if not (world and world.local_ship and world.local_ship.transform and world.local_ship.sector) then
        return
    end

    local ship = world.local_ship

    drawBackgroundOverlay()

    local wx, wy, ww, wh = getWindowRect(world)
    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Sector Map",
        bottomText = nil,
        showClose = true,
    })

    local content = layout.content

    local bg = Theme.getBackgroundColor()
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.96)
    love.graphics.rectangle("fill", content.x, content.y, content.w, content.h)

    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", content.x, content.y, content.w, content.h)

    local mid_x = content.x + content.w * 0.5
    local mid_y = content.y + content.h * 0.5
    love.graphics.setColor(0.18, 0.32, 0.50, 0.6)
    love.graphics.line(content.x, mid_y, content.x + content.w, mid_y)
    love.graphics.line(mid_x, content.y, mid_x, content.y + content.h)

    for _, e in ipairs(world:getEntities()) do
        if (e.asteroid or e.asteroid_chunk or e.vehicle or e.station) and e.transform then
            local px, py = worldToMap(content, ship, e)
            if px and py then
                if e == ship then
                    love.graphics.setColor(0.1, 1.0, 0.3, 1.0)
                    love.graphics.circle("fill", px, py, 4)
                elseif e.station then
                    love.graphics.setColor(0.40, 0.80, 1.00, 1.0)
                    love.graphics.rectangle("fill", px - 4, py - 4, 8, 8)
                elseif e.vehicle then
                    if e.ai then
                        love.graphics.setColor(1.0, 0.25, 0.25, 1.0)
                    else
                        love.graphics.setColor(0.25, 0.6, 1.0, 1.0)
                    end
                    love.graphics.circle("fill", px, py, 3)

                    if not e.ai and e ~= ship and e.name and e.name.value then
                        local name = e.name.value
                        local font = love.graphics.getFont()
                        local text_w = font:getWidth(name)
                        local text_h = font:getHeight()

                        love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                        love.graphics.print(name, px - text_w * 0.5, py - 3 - text_h - 2)
                    end
                elseif e.asteroid or e.asteroid_chunk then
                    love.graphics.setColor(0.70, 0.70, 0.70, 1.0)
                    love.graphics.circle("fill", px, py, 2)
                end
            end
        end
    end

    local font = Theme.getFont("chat")
    love.graphics.setFont(font)

    local padding = 8
    local line_h = font:getHeight()

    love.graphics.setColor(Theme.colors.textPrimary)

    local legend_x = content.x + padding
    local legend_y = content.y + padding

    love.graphics.print("Legend", legend_x, legend_y)
    legend_y = legend_y + line_h + 2

    local icon_radius = 4
    local text_offset_x = icon_radius * 3

    love.graphics.setColor(0.1, 1.0, 0.3, 1.0)
    love.graphics.circle("fill", legend_x + icon_radius, legend_y + line_h * 0.5, icon_radius)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("You", legend_x + text_offset_x, legend_y)
    legend_y = legend_y + line_h

    love.graphics.setColor(0.25, 0.6, 1.0, 1.0)
    love.graphics.circle("fill", legend_x + icon_radius, legend_y + line_h * 0.5, icon_radius - 1)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Remote Player", legend_x + text_offset_x, legend_y)
    legend_y = legend_y + line_h

    love.graphics.setColor(1.0, 0.25, 0.25, 1.0)
    love.graphics.circle("fill", legend_x + icon_radius, legend_y + line_h * 0.5, icon_radius - 1)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Ship", legend_x + text_offset_x, legend_y)
    legend_y = legend_y + line_h

    love.graphics.setColor(0.40, 0.80, 1.00, 1.0)
    love.graphics.rectangle("fill", legend_x + icon_radius - 3, legend_y + line_h * 0.5 - 3, 6, 6)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Station", legend_x + text_offset_x, legend_y)
    legend_y = legend_y + line_h

    love.graphics.setColor(0.70, 0.70, 0.70, 1.0)
    love.graphics.circle("fill", legend_x + icon_radius, legend_y + line_h * 0.5, icon_radius - 2)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Asteroid", legend_x + text_offset_x, legend_y)

    local sector = ship.sector or { x = 0, y = 0 }
    local sector_text = string.format("Sector: %d, %d", sector.x or 0, sector.y or 0)
    local pos_text = string.format("Pos: %.0f, %.0f", ship.transform.x, ship.transform.y)

    local sector_w = font:getWidth(sector_text)
    local pos_w = font:getWidth(pos_text)
    local max_w = math.max(sector_w, pos_w)

    local info_x = content.x + content.w - padding - max_w
    local info_y = content.y + padding

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(sector_text, info_x, info_y)
    love.graphics.print(pos_text, info_x, info_y + line_h)
end

function MapPanel.update(dt, world)
    local ui = world and world.ui
    if ui and ui.map_drag and ui.map_drag.active and ui.map_open then
        local mx, my = love.mouse.getPosition()
        local wx, wy, ww, wh = getWindowRect(world)

        local drag = ui.map_drag
        local new_x = mx - (drag.offset_x or 0)
        local new_y = my - (drag.offset_y or 0)

        local sw, sh = love.graphics.getDimensions()
        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        ui.map_window = ui.map_window or {}
        ui.map_window.x = new_x
        ui.map_window.y = new_y
        ui.map_window.width = ww
        ui.map_window.height = wh
        return true
    end
    return false
end

function MapPanel.mousepressed(x, y, button, world)
    if button ~= 1 then return false end
    if not (world and world.ui and world.ui.map_open) then return false end

    local wx, wy, ww, wh = getWindowRect(world)
    local layout = Window.getLayout({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
    })

    local r = layout.close
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        world.ui.map_open = false
        if world.ui.map_drag then
            world.ui.map_drag.active = false
        end
        return true
    end

    local tb = layout.titleBar
    if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
        local ui = world.ui
        ui.map_drag = ui.map_drag or {}
        ui.map_drag.active = true
        ui.map_drag.offset_x = x - wx
        ui.map_drag.offset_y = y - wy

        ui.map_window = ui.map_window or {}
        ui.map_window.width = ww
        ui.map_window.height = wh
        return true
    end

    return false
end

function MapPanel.mousereleased(x, y, button, world)
    if button ~= 1 then return false end
    local ui = world and world.ui
    if ui and ui.map_drag and ui.map_drag.active then
        ui.map_drag.active = false
        return true
    end
    return false
end

return MapPanel
