local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"
local ItemSpawners = require "src.ecs.spawners.item"
local ItemDefinitions = require "src.data.items"
local FloatingTextSpawner = require "src.utils.floating_text_spawner"

local CargoPanel = {}

-- Cache for item icon shapes to prevent regeneration each frame
local icon_shape_cache = {}

local function getOrderedItems(world, cargo)
    local items_map = {}
    for name, count in pairs(cargo.items or {}) do
        items_map[name] = count
    end

    local ordered_names = {}
    local ui = world and world.ui

    if ui then
        ui.cargo_item_order = ui.cargo_item_order or {}
        local existing_order = ui.cargo_item_order
        local present = {}

        for name, _ in pairs(items_map) do
            present[name] = true
        end

        for _, name in ipairs(existing_order) do
            if present[name] then
                table.insert(ordered_names, name)
                present[name] = nil
            end
        end

        local remaining = {}
        for name, _ in pairs(present) do
            table.insert(remaining, name)
        end
        table.sort(remaining)
        for _, name in ipairs(remaining) do
            table.insert(ordered_names, name)
        end

        ui.cargo_item_order = ordered_names
    else
        for name, _ in pairs(items_map) do
            table.insert(ordered_names, name)
        end
        table.sort(ordered_names)
    end

    local ordered_items = {}
    for _, name in ipairs(ordered_names) do
        local count = items_map[name]
        if count then
            local volume = 0
            if cargo.item_volumes and cargo.item_volumes[name] then
                volume = cargo.item_volumes[name]
            end
            table.insert(ordered_items, { name = name, count = count, volume = volume })
        end
    end

    return ordered_items
end

local function jettisonCargoItem(world, amount, item_name, screen_x, screen_y)
    if not (world and world.local_ship and world.local_ship.cargo and amount and amount > 0 and item_name) then
        return
    end
    local ship = world.local_ship
    local cargo = ship.cargo
    local item_count = cargo.items and cargo.items[item_name] or 0
    if not item_count or item_count <= 0 then
        return
    end
    local def_id
    local def
    for id, d in pairs(ItemDefinitions) do
        if d.name == item_name then
            def_id = id
            def = d
            break
        end
    end
    if not def_id or not def then
        return
    end
    local drop_amount = math.min(amount, item_count)
    if drop_amount <= 0 then
        return
    end
    local mx, my = screen_x, screen_y
    if not mx or not my then
        mx, my = love.mouse.getPosition()
    end
    local world_x, world_y = mx, my
    if world.camera and world.camera.worldCoords then
        world_x, world_y = world.camera:worldCoords(mx, my)
    end
    local sector = ship.sector
    local sector_x = sector and sector.x or 0
    local sector_y = sector and sector.y or 0
    for i = 1, drop_amount do
        ItemSpawners.spawn_item(world, def_id, world_x, world_y, sector_x, sector_y, nil, nil)
    end
    local unit_volume = def.volume or 1.0
    local unit_mass = (def.physics and def.physics.mass) or 0
    local total_volume = drop_amount * unit_volume
    local total_mass = drop_amount * unit_mass
    cargo.current = math.max(0, (cargo.current or 0) - total_volume)
    cargo.mass = math.max(0, (cargo.mass or 0) - total_mass)
    local new_count = item_count - drop_amount
    cargo.items[item_name] = new_count > 0 and new_count or nil
    cargo.item_volumes = cargo.item_volumes or {}
    local new_volume = math.max(0, (cargo.item_volumes[item_name] or 0) - total_volume)
    cargo.item_volumes[item_name] = new_volume > 0 and new_volume or nil
    local ui = world.ui
    if ui and ui.cargo_item_order and new_count <= 0 then
        local order = ui.cargo_item_order
        for i, name in ipairs(order) do
            if name == item_name then
                table.remove(order, i)
                break
            end
        end
    end
    if ship.physics and ship.physics.body and total_mass > 0 then
        local body = ship.physics.body
        local current_mass = body:getMass()
        body:setMass(math.max(0.1, current_mass - total_mass))
    end
    local text = string.format("Jettisoned %d %s", drop_amount, tostring(item_name))
    FloatingTextSpawner.spawn(world, text, world_x, world_y, { 1, 0.7, 0.2, 1 })
end

local function drawJettisonDialog(world, jd, wx, wy, ww, wh)
    if not (world and jd and jd.active) then
        return
    end
    local font = Theme.getFont("chat")
    love.graphics.setFont(font)
    local dialog_w = 260
    local dialog_h = 140
    local dx = wx + (ww - dialog_w) * 0.5
    local dy = wy + (wh - dialog_h) * 0.5
    jd.dialog_x = dx
    jd.dialog_y = dy
    jd.dialog_w = dialog_w
    jd.dialog_h = dialog_h
    local shapes = Theme.shapes
    local r = shapes.panelCornerRadius or 4
    local bg = Theme.colors.window and Theme.colors.window.titleBar or { 0.06, 0.08, 0.16, 1.0 }
    love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] or 1)
    love.graphics.rectangle("fill", dx, dy, dialog_w, dialog_h, r, r)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.setLineWidth(shapes.outlineWidth or 1)
    love.graphics.rectangle("line", dx, dy, dialog_w, dialog_h, r, r)
    local padding = 10
    local line_h = font:getHeight()
    love.graphics.setColor(Theme.colors.textPrimary)
    local title = "Jettison item"
    love.graphics.printf(title, dx + padding, dy + padding, dialog_w - padding * 2, "center")
    local item_label = string.format("%s (max %d)", tostring(jd.item_name or ""), jd.max_amount or 0)
    love.graphics.printf(item_label, dx + padding, dy + padding + line_h + 4, dialog_w - padding * 2, "center")
    local slider_y = dy + padding + line_h * 2 + 14
    local slider_x = dx + padding
    local slider_w = dialog_w - padding * 2 - 70
    local slider_h = 6
    jd.slider_x = slider_x
    jd.slider_y = slider_y
    jd.slider_w = slider_w
    jd.slider_h = slider_h
    love.graphics.setColor(0.2, 0.2, 0.25, 1)
    love.graphics.rectangle("fill", slider_x, slider_y, slider_w, slider_h, 3, 3)
    local max_amount = math.max(1, jd.max_amount or 1)
    local amount = math.max(1, math.min(jd.amount or 1, max_amount))
    jd.amount = amount
    local t = max_amount > 1 and ((amount - 1) / (max_amount - 1)) or 0
    local handle_x = slider_x + t * slider_w
    local handle_r = 7
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.circle("fill", handle_x, slider_y + slider_h * 0.5, handle_r)
    local amount_box_w = 60
    local amount_box_h = line_h + 6
    local amount_box_x = slider_x + slider_w + 10
    local amount_box_y = slider_y - (amount_box_h - slider_h) * 0.5
    jd.amount_x = amount_box_x
    jd.amount_y = amount_box_y
    jd.amount_w = amount_box_w
    jd.amount_h = amount_box_h
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", amount_box_x, amount_box_y, amount_box_w, amount_box_h, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", amount_box_x, amount_box_y, amount_box_w, amount_box_h, 3, 3)
    local amount_text = tostring(amount)
    love.graphics.printf(amount_text, amount_box_x, amount_box_y + (amount_box_h - line_h) * 0.5, amount_box_w, "center")
    local button_w = (dialog_w - padding * 3) * 0.5
    local button_h = 22
    local button_y = dy + dialog_h - padding - button_h
    local confirm_x = dx + padding
    local cancel_x = confirm_x + button_w + padding
    jd.confirm_x = confirm_x
    jd.confirm_y = button_y
    jd.confirm_w = button_w
    jd.confirm_h = button_h
    jd.cancel_x = cancel_x
    jd.cancel_y = button_y
    jd.cancel_w = button_w
    jd.cancel_h = button_h
    love.graphics.setColor(0.1, 0.4, 0.2, 1.0)
    love.graphics.rectangle("fill", confirm_x, button_y, button_w, button_h, r, r)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("line", confirm_x, button_y, button_w, button_h, r, r)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Confirm", confirm_x, button_y + (button_h - line_h) * 0.5, button_w, "center")
    love.graphics.setColor(0.3, 0.1, 0.1, 1.0)
    love.graphics.rectangle("fill", cancel_x, button_y, button_w, button_h, r, r)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("line", cancel_x, button_y, button_w, button_h, r, r)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Cancel", cancel_x, button_y + (button_h - line_h) * 0.5, button_w, "center")
end

function CargoPanel.getWindowRect(world)
    local sw, sh = love.graphics.getDimensions()

    local spacing = Theme.spacing
    local defaultWidth = spacing.cargoWindowWidth or 720
    local defaultHeight = spacing.cargoWindowHeight or 420

    local ui = world and world.ui
    if ui and ui.cargo_window then
        local w = ui.cargo_window
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

function CargoPanel.draw(world, player)
    if not player then
        return
    end

    local spacing = Theme.spacing
    local shapes = Theme.shapes

    -- Find the ship (if any)
    local ship
    if player.controlling and player.controlling.entity then
        ship = player.controlling.entity
    end

    local cargo = ship and ship.cargo or player.cargo
    if not cargo then
        return
    end

    local used = cargo.current or 0
    local capacity = cargo.capacity or 0
    local mass = cargo.mass or 0

    local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Cargo",
        bottomText = "",
        showClose = true,
    })

    -- Draw custom bottom bar with volume/mass info and capacity bar
    local bottomBar = layout.bottomBar
    local fontLabel = Theme.getFont("chat")
    love.graphics.setFont(fontLabel)

    -- Volume and mass text with proper units (ASCII-friendly)
    local infoText = string.format("Volume: %.1f/%.1f m3  |  Mass: %.1f kg", used, capacity, mass)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(infoText, bottomBar.x + 10, bottomBar.y + 4)

    -- Capacity bar on the right side of bottom bar
    local barWidth = spacing.cargoCapacityBarWidth or 150
    local barHeight = spacing.cargoCapacityBarHeight or 14
    local barX = bottomBar.x + bottomBar.w - barWidth - 10
    local barY = bottomBar.y + (bottomBar.h - barHeight) * 0.5

    local pct = 0
    if capacity > 0 then
        pct = math.max(0, math.min(1, used / capacity))
    end

    -- Bar background
    local cColors = Theme.colors.cargo
    love.graphics.setColor(cColors.barBackground)
    local slotCornerRadius = shapes.slotCornerRadius or 2
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, slotCornerRadius, slotCornerRadius)

    -- Bar fill
    if pct > 0 then
        local fillColor = cColors.barFill
        if pct > 0.9 then
            fillColor = cColors.barFillCritical
        elseif pct > 0.7 then
            fillColor = cColors.barFillWarning
        end
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", barX, barY, barWidth * pct, barHeight, slotCornerRadius, slotCornerRadius)
    end

    -- Bar outline
    love.graphics.setColor(cColors.barOutline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, slotCornerRadius, slotCornerRadius)

    -- Percentage text on bar
    
    local content = layout.content
    local cx, cy, cw, ch = content.x, content.y, content.w, content.h

    local fontText = Theme.getFont("chat")
    love.graphics.setFont(fontText)

    local ui = world and world.ui
    if ui then
        ui.cargo_slots = {}
    end

    -- Grid of item "slots" inside the content area (RuneScape-style, invisible slots)
    local items = getOrderedItems(world, cargo)

    if #items == 0 then
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print("Empty", cx, cy)
        return
    end

    local slotSize = spacing.cargoSlotSize or 96 -- Increased from 32 to fit icon + text
    local slotGap = spacing.cargoSlotGap or 8
    local cols = math.max(1, math.floor((cw + slotGap) / (slotSize + slotGap)))

    -- Load item definitions for rendering icons

    local drag = ui and ui.cargo_item_drag
    local drag_index = drag and drag.active and drag.index or nil
    local drag_item = nil

    local function drawItem(it, sx, sy)

        local item_def = ItemDefinitions[it.name:lower()]
        if item_def and item_def.render then
            love.graphics.push()
            love.graphics.translate(sx + slotSize * 0.5, sy + slotSize * 0.5)

            local cache_key = it.name:lower()
            local vertices = icon_shape_cache[cache_key]
            if not vertices then
                vertices = item_def:generate_shape()
                icon_shape_cache[cache_key] = vertices
            end

            local color = item_def.render.color or { 0.6, 0.6, 0.65, 1 }

            local baseSlotSize = 64
            local scale = (slotSize / baseSlotSize) * 3.0
            love.graphics.push()
            love.graphics.scale(scale, scale)

            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            if vertices and #vertices >= 6 then
                love.graphics.polygon("fill", vertices)
                love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, (color[4] or 1))
                love.graphics.setLineWidth(0.5)
                love.graphics.polygon("line", vertices)
            end

            love.graphics.pop()
            love.graphics.pop()
        end

        local amount = it.count or 0
        local amountText = tostring(amount)
        local amountW = fontText:getWidth(amountText)
        local amountH = fontText:getHeight()

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill",
            sx + (slotSize - amountW) * 0.5 - 2,
            sy + 2,
            amountW + 4,
            amountH + 2,
            1, 1)

        love.graphics.setColor(cColors.textCount)
        love.graphics.print(amountText, sx + (slotSize - amountW) * 0.5, sy + 2)

        local nameText = it.name
        local nameW = fontText:getWidth(nameText)
        local nameX = sx + (slotSize - nameW) * 0.5
        local nameY = sy + slotSize - amountH - 2

        love.graphics.setColor(cColors.textName)
        love.graphics.print(nameText, nameX, nameY)
    end

    for index, it in ipairs(items) do
        local idx = index - 1
        local col = idx % cols
        local row = math.floor(idx / cols)

        local sx = cx + col * (slotSize + slotGap)
        local sy = cy + row * (slotSize + slotGap)

        if sy + slotSize > cy + ch then
            break
        end

        if ui and ui.cargo_slots then
            ui.cargo_slots[index] = { x = sx, y = sy, w = slotSize, h = slotSize, item = it }
        end

        if drag_index == index then
            drag_item = it
        else
            drawItem(it, sx, sy)
        end
    end

    if drag and drag.active and drag_item and drag_index then
        local mx, my = love.mouse.getPosition()
        local sx = mx - (drag.offset_x or (slotSize * 0.5))
        local sy = my - (drag.offset_y or (slotSize * 0.5))
        drawItem(drag_item, sx, sy)
    end

    if ui and ui.cargo_jettison and ui.cargo_jettison.active then
        drawJettisonDialog(world, ui.cargo_jettison, wx, wy, ww, wh)
    end
end

function CargoPanel.update(dt, world)
    local ui = world and world.ui
    if ui and ui.cargo_drag and ui.cargo_drag.active and ui.cargo_open then
        local mx, my = love.mouse.getPosition()
        local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

        local drag = ui.cargo_drag
        local new_x = mx - drag.offset_x
        local new_y = my - drag.offset_y

        local sw, sh = love.graphics.getDimensions()
        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.x = new_x
        ui.cargo_window.y = new_y
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
        return true
    end
    return false
end

function CargoPanel.mousepressed(x, y, button, world)
    if button ~= 1 then return false end
    if not (world and world.ui and world.ui.cargo_open) then return false end

    local ui = world.ui
    if ui.cargo_jettison and ui.cargo_jettison.active then
        local jd = ui.cargo_jettison
        if jd.confirm_x and x >= jd.confirm_x and x <= jd.confirm_x + jd.confirm_w and
            y >= jd.confirm_y and y <= jd.confirm_y + jd.confirm_h then
            jettisonCargoItem(world, jd.amount or 1, jd.item_name, jd.screen_x, jd.screen_y)
            jd.active = false
            return true
        end
        if jd.cancel_x and x >= jd.cancel_x and x <= jd.cancel_x + jd.cancel_w and
            y >= jd.cancel_y and y <= jd.cancel_y + jd.cancel_h then
            jd.active = false
            return true
        end
        if jd.slider_x and jd.slider_w and jd.slider_w > 0 and
            x >= jd.slider_x and x <= jd.slider_x + jd.slider_w and
            y >= jd.slider_y - 8 and y <= jd.slider_y + jd.slider_h + 8 then
            if jd.max_amount and jd.max_amount > 0 then
                local t = (x - jd.slider_x) / jd.slider_w
                if t < 0 then t = 0 end
                if t > 1 then t = 1 end
                local max_amount = math.max(1, jd.max_amount)
                local amount = 1 + math.floor(t * (max_amount - 1) + 0.5)
                jd.amount = amount
            end
            return true
        end
    end

    local wx, wy, ww, wh = CargoPanel.getWindowRect(world)
    local layout = Window.getLayout({ x = wx, y = wy, width = ww, height = wh })
    local r = layout.close

    -- Close button
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        world.ui.cargo_open = false
        if world.ui.cargo_drag then
            world.ui.cargo_drag.active = false
        end
        return true -- Consumed
    end

    -- Begin dragging when clicking the title bar (excluding close button)
    local tb = layout.titleBar
    if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
        ui = world.ui
        ui.cargo_drag = ui.cargo_drag or {}
        ui.cargo_drag.active = true
        ui.cargo_drag.offset_x = x - wx
        ui.cargo_drag.offset_y = y - wy

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
        return true -- Consumed
    end

    local ui = world.ui
    if ui and ui.cargo_slots then
        for index, slot in ipairs(ui.cargo_slots) do
            if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
                ui.cargo_item_drag = ui.cargo_item_drag or {}
                ui.cargo_item_drag.active = true
                ui.cargo_item_drag.index = index
                ui.cargo_item_drag.item_name = slot.item and slot.item.name or nil
                ui.cargo_item_drag.offset_x = x - slot.x
                ui.cargo_item_drag.offset_y = y - slot.y
                return true
            end
        end
    end

    return false
end

function CargoPanel.mousereleased(x, y, button, world)
    if button ~= 1 then return false end
    if not (world and world.ui) then return false end

    local ui = world.ui
    local consumed = false

    if ui.cargo_item_drag and ui.cargo_item_drag.active then
        local drag = ui.cargo_item_drag
        local slots = ui.cargo_slots or {}
        local order = ui.cargo_item_order or {}

        local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

        local target_index
        for index, slot in ipairs(slots) do
            if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
                target_index = index
                break
            end
        end

        local from_index = drag.index
        local dropped_outside_window = not (x >= wx and x <= wx + ww and y >= wy and y <= wy + wh)

        if not target_index and from_index and dropped_outside_window then
            local slot = slots[from_index]
            if slot and slot.item and world.local_ship and world.local_ship.cargo then
                local ship = world.local_ship
                local cargo = ship.cargo
                local item_name = slot.item.name
                local item_count = cargo.items and cargo.items[item_name] or 0
                if item_count and item_count > 0 then
                    ui.cargo_jettison = ui.cargo_jettison or {}
                    local jd = ui.cargo_jettison
                    jd.active = true
                    jd.item_name = item_name
                    jd.slot_index = from_index
                    jd.max_amount = item_count
                    jd.amount = math.min(jd.amount or 1, item_count)
                    jd.screen_x = x
                    jd.screen_y = y
                end
            end
        elseif target_index and from_index and from_index ~= target_index and order[from_index] then
            local name = table.remove(order, from_index)
            if name then
                if target_index > #order + 1 then
                    target_index = #order + 1
                end
                table.insert(order, target_index, name)
            end
        end

        drag.active = false
        drag.index = nil
        drag.item_name = nil
        consumed = true
    end

    if ui.cargo_drag and ui.cargo_drag.active then
        ui.cargo_drag.active = false
        consumed = true
    end

    if consumed then
        return true
    end

    return false
end

return CargoPanel
