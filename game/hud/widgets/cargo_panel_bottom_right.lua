local Theme = require("game.theme")
local Items = require("game.items")
local Inventory = require("game.inventory")
local ItemIcons = require("game.item_icons")

local function getPlayerShip(world)
  local player = world and world:getResource("player")
  if player and player.pilot and player.pilot.ship then
    return player.pilot.ship
  end
  return nil
end

local function pointInRect(px, py, r)
  return px >= r.x and px <= (r.x + r.w) and py >= r.y and py <= (r.y + r.h)
end

local function spawnPickup(ctx, id, volume, worldX, worldY)
  if not ctx or not ctx.world or not id or not volume or volume <= 0 then
    return false
  end

  local physicsWorld = ctx.world:getResource("physics")
  if not physicsWorld then
    return false
  end

  local def = Items.get(id)
  local color = (def and def.color) or { 1, 1, 1, 0.95 }

  local body = love.physics.newBody(physicsWorld, worldX or 0, worldY or 0, "dynamic")
  body:setLinearDamping(3.5)
  body:setAngularDamping(6.0)

  local shape = love.physics.newCircleShape(6)
  local fixture = love.physics.newFixture(body, shape, 0.2)
  fixture:setSensor(true)
  fixture:setCategory(16)
  fixture:setMask(1, 4, 8, 16)

  local e = ctx.world:newEntity()
    :give("physics_body", body, shape, fixture)
    :give("renderable", "pickup", color)
    :give("pickup", id, volume)

  fixture:setUserData(e)
  return true
end

local function makeCargoPanel()
  local self = {
    open = true,
    bounds = nil,
    slotRects = {},
    drag = nil,
    dragFrom = nil,
    scrollRow = 0,
    scrollDrag = false,
    scrollDragOffsetY = 0,
  }

  local function getDisplayRows(hold, displayCols)
    if not hold then
      return 0
    end
    local totalSlots = (hold.cols or 0) * (hold.rows or 0)
    if totalSlots <= 0 and hold.slots then
      for _ in pairs(hold.slots) do
        totalSlots = totalSlots + 1
      end
    end
    if totalSlots <= 0 or not displayCols or displayCols <= 0 then
      return 0
    end
    return math.ceil(totalSlots / displayCols)
  end

  local function recomputeRects(ctx, cols, rows)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local cp = hudTheme.cargoPanel or {}

    local margin = (ctx.layout and ctx.layout.margin) or hudTheme.layout.margin
    local screenW = ctx and ctx.screenW or 0
    local yBottom = (ctx.layout and ctx.layout.bottomRightY) or ((ctx and ctx.screenH or 0) - margin)

    local pad = cp.pad or 6
    local headerH = cp.headerH or 0
    local slot = cp.slot or 44
    local gap = cp.gap or 6
    local barGap = cp.barGap or 6
    local barH = cp.barH or 10
    local visibleRows = cp.visibleRows or 4
    local scrollGap = cp.scrollGap or 6
    local scrollW = cp.scrollW or 6

    local maxScroll = rows - visibleRows
    if maxScroll < 0 then
      maxScroll = 0
    end

    if self.scrollRow < 0 then
      self.scrollRow = 0
    elseif self.scrollRow > maxScroll then
      self.scrollRow = maxScroll
    end

    local gridW = cols * slot + (cols - 1) * gap
    local gridH = visibleRows * slot + (visibleRows - 1) * gap

    local panelW = pad * 2 + gridW + scrollGap + scrollW
    local panelH = pad * 2 + headerH + gridH + barGap + barH

    local panelDrawH = panelH
    local x0 = screenW - margin - panelW
    local y0 = yBottom - panelDrawH

    self.bounds = {
      x = x0,
      y = y0,
      w = panelW,
      h = panelDrawH,
      pad = pad,
      headerH = headerH,
      slot = slot,
      gap = gap,
      barGap = barGap,
      barH = barH,
      visibleRows = visibleRows,
      scrollGap = scrollGap,
      scrollW = scrollW,
      scrollMax = maxScroll,
      gridX = x0 + pad,
      gridY = y0 + pad + headerH,
      gridW = gridW,
      gridH = gridH,
      cols = cols,
      rows = rows,
    }

    self.bounds.scrollTrack = nil
    self.bounds.scrollThumb = nil

    local clearN = cols * rows
    if #self.slotRects > clearN then
      clearN = #self.slotRects
    end
    for i = 1, clearN do
      self.slotRects[i] = nil
    end

    if self.open then
      local gridX = x0 + pad
      local gridY = y0 + pad + headerH
      local idx = 1
      for r = 1, visibleRows do
        for c = 1, cols do
          local sx = gridX + (c - 1) * (slot + gap)
          local sy = gridY + (r - 1) * (slot + gap)
          local row = r + self.scrollRow
          local slotIdx = (row - 1) * cols + c
          self.slotRects[idx] = { x = sx, y = sy, w = slot, h = slot, idx = slotIdx }
          idx = idx + 1
        end
      end

      local trackX = gridX + gridW + scrollGap
      local trackY = gridY
      local trackH = gridH

      local thumbH = trackH
      if rows > 0 then
        thumbH = math.floor(trackH * (visibleRows / rows))
      end
      local thumbMinH = cp.scrollThumbMinH or 18
      if thumbH < thumbMinH then
        thumbH = thumbMinH
      end
      if thumbH > trackH then
        thumbH = trackH
      end

      local t = 0
      if maxScroll > 0 then
        t = self.scrollRow / maxScroll
      end
      local thumbY = trackY + (trackH - thumbH) * t

      self.bounds.scrollTrack = { x = trackX, y = trackY, w = scrollW, h = trackH }
      self.bounds.scrollThumb = { x = trackX, y = thumbY, w = scrollW, h = thumbH }
    end
  end

  local function pickSlot(mx, my)
    if not self.open then
      return nil
    end

    for i = 1, #self.slotRects do
      local r = self.slotRects[i]
      if r and pointInRect(mx, my, r) then
        return r.idx
      end
    end

    return nil
  end

  function self.hitTest(ctx, x, y)
    if not ctx then
      return false
    end

    local ship = ctx.world and getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold then
      return false
    end

    local theme = (ctx and ctx.theme) or Theme
    local displayCols = (theme.hud.cargoPanel and theme.hud.cargoPanel.displayCols) or 2
    local displayRows = getDisplayRows(ship.cargo_hold, displayCols)
    recomputeRects(ctx, displayCols, displayRows)

    local b = self.bounds
    if not b then
      return false
    end

    return pointInRect(x, y, b)
  end

  function self.draw(ctx)
    if not ctx then
      return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local ship = getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return
    end

    local hold = ship.cargo_hold
    local cargo = ship.cargo

    local displayCols = (hudTheme.cargoPanel and hudTheme.cargoPanel.displayCols) or 2
    local displayRows = getDisplayRows(hold, displayCols)

    recomputeRects(ctx, displayCols, displayRows)

    local colors = hudTheme.colors

    local b = self.bounds

    if not b then
      return
    end

    love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4])
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)

    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], colors.panelBorder[4])
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h)

    local used = cargo.used or 0
    local cap = cargo.capacity or 0

    if self.scrollDrag then
      local mx0, my0 = love.mouse.getPosition()
      if not love.mouse.isDown(1) then
        self.scrollDrag = false
      else
        local track = b.scrollTrack
        local thumb = b.scrollThumb
        if track and thumb and b.scrollMax and b.scrollMax > 0 then
          local minY = track.y
          local maxY = track.y + track.h - thumb.h
          local ty = my0 - (self.scrollDragOffsetY or 0)
          if ty < minY then
            ty = minY
          elseif ty > maxY then
            ty = maxY
          end
          local t = (maxY > minY) and ((ty - minY) / (maxY - minY)) or 0
          local row = math.floor(t * b.scrollMax + 0.5)
          if row < 0 then
            row = 0
          elseif row > b.scrollMax then
            row = b.scrollMax
          end
          if row ~= self.scrollRow then
            self.scrollRow = row
            recomputeRects(ctx, displayCols, displayRows)
            b = self.bounds
            if not b then
              return
            end
          end
        end
      end
    end

    if self.open then
      local mx, my = love.mouse.getPosition()
      local hover = pickSlot(mx, my)

      for i = 1, #self.slotRects do
        local r = self.slotRects[i]
        local slot = r and r.idx and hold.slots[r.idx] or nil
        if self.dragFrom and r and r.idx == self.dragFrom then
          slot = nil
        end

        if r then

          local isHover = hover == (r and r.idx)
          love.graphics.setColor(0, 0, 0, isHover and 0.55 or 0.35)
          love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)

          love.graphics.setColor(1, 1, 1, isHover and 0.55 or 0.25)
          love.graphics.rectangle("line", r.x, r.y, r.w, r.h)

          if slot and slot.id and slot.volume and slot.volume > 0 then
            local def = Items.get(slot.id)
            local c = (def and def.color) or { 1, 1, 1, 0.9 }

            if slot.id == "stone" then
              ItemIcons.draw(slot.id, r.x + 3, r.y + 3, r.w - 6, r.h - 6, { tint = { 1, 1, 1, 0.95 } })
            else
              love.graphics.setColor(c[1], c[2], c[3], 0.75)
              love.graphics.rectangle("fill", r.x + 3, r.y + 3, r.w - 6, r.h - 6)
            end

            local countText = tostring(math.floor(slot.volume)) .. "m3"
            local font = love.graphics.getFont()
            local tw = font:getWidth(countText)
            local th = font:getHeight()

            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.print(countText, r.x + r.w - tw - 4 + 1, r.y + r.h - th - 2 + 1)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.print(countText, r.x + r.w - tw - 4, r.y + r.h - th - 2)
          end
        end
      end

      if self.drag and self.drag.id and self.drag.volume and self.drag.volume > 0 then
        local mx2, my2 = love.mouse.getPosition()
        local def = Items.get(self.drag.id)
        local c = (def and def.color) or { 1, 1, 1, 0.9 }

        local slotSize = b.slot or 28
        local dragSize = math.max(28, math.floor(slotSize * 0.6))
        local dragHalf = dragSize * 0.5

        if self.drag.id == "stone" then
          ItemIcons.draw(self.drag.id, mx2 - dragHalf, my2 - dragHalf, dragSize, dragSize, { tint = { 1, 1, 1, 0.9 } })
        else
          love.graphics.setColor(c[1], c[2], c[3], 0.7)
          love.graphics.rectangle("fill", mx2 - dragHalf, my2 - dragHalf, dragSize, dragSize)
          love.graphics.setColor(1, 1, 1, 0.35)
          love.graphics.rectangle("line", mx2 - dragHalf, my2 - dragHalf, dragSize, dragSize)
        end

        local countText = tostring(math.floor(self.drag.volume)) .. "m3"
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(countText, mx2 + 16 + 1, my2 - 10 + 1)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(countText, mx2 + 16, my2 - 10)
      end
    end

    do
      local track = b.scrollTrack
      local thumb = b.scrollThumb
      local maxScroll = b.scrollMax
      if track and thumb and maxScroll and maxScroll > 0 then
        love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4])
        love.graphics.rectangle("fill", track.x, track.y, track.w, track.h)
        love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
        love.graphics.rectangle("line", track.x, track.y, track.w, track.h)

        love.graphics.setColor(colors.barFillSecondary[1], colors.barFillSecondary[2], colors.barFillSecondary[3], colors.barFillSecondary[4])
        love.graphics.rectangle("fill", thumb.x, thumb.y, thumb.w, thumb.h)
        love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
        love.graphics.rectangle("line", thumb.x, thumb.y, thumb.w, thumb.h)
      end
    end

    do
      local barX = b.x + b.pad
      local barY = b.y + b.h - b.pad - (b.barH or 12)
      local barW = b.w - b.pad * 2
      local barH = b.barH or 12

      local frac = 0
      if cap > 0 then
        frac = used / cap
        if frac < 0 then
          frac = 0
        elseif frac > 1 then
          frac = 1
        end
      end

      love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4])
      love.graphics.rectangle("fill", barX, barY, barW, barH)

      local theme = (ctx and ctx.theme) or Theme
      local cp = theme.hud.cargoPanel or {}
      local warnFrac = cp.warnFrac or 0.85
      local dangerFrac = cp.dangerFrac or 0.95

      local fill
      if frac < warnFrac then
        fill = colors.good
      elseif frac < dangerFrac then
        fill = colors.warn
      else
        fill = colors.danger
      end
      love.graphics.setColor(fill[1], fill[2], fill[3], fill[4])
      love.graphics.rectangle("fill", barX, barY, barW * frac, barH)

      love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
      love.graphics.rectangle("line", barX, barY, barW, barH)

      local percent = math.floor(frac * 100 + 0.5)
      local label = tostring(percent) .. "%"

      local font = love.graphics.getFont()
      local tw = font:getWidth(label)
      local th = font:getHeight()
      local padX = 4
      local maxTw = barW - padX * 2
      local sx = 1
      if tw > 0 and maxTw > 0 and tw > maxTw then
        sx = maxTw / tw
      end

      local tx = barX + (barW - tw * sx) * 0.5
      local ty = barY + (barH - th) * 0.5

      love.graphics.push()
      love.graphics.translate(tx, ty)
      love.graphics.scale(sx, 1)
      love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
      love.graphics.print(label, 1, 1)
      love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
      love.graphics.print(label, 0, 0)
      love.graphics.pop()
    end

    if ctx.layout then
      local stackGap = (hudTheme.layout and hudTheme.layout.stackGap) or 0
      ctx.layout.bottomRightY = b.y - stackGap
    end

    love.graphics.setColor(1, 1, 1, 1)
  end

  function self.mousepressed(ctx, x, y, button)
    local ship = ctx and ctx.world and getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return false
    end

    local hold = ship.cargo_hold
    local theme = (ctx and ctx.theme) or Theme
    local displayCols = (theme.hud.cargoPanel and theme.hud.cargoPanel.displayCols) or 2
    local displayRows = getDisplayRows(hold, displayCols)
    recomputeRects(ctx, displayCols, displayRows)

    local b = self.bounds
    if not b then
      return false
    end

    if not pointInRect(x, y, b) then
      return false
    end

    if button ~= 1 then
      return true
    end

    if b.scrollTrack and pointInRect(x, y, b.scrollTrack) then
      if b.scrollThumb and pointInRect(x, y, b.scrollThumb) then
        self.scrollDrag = true
        self.scrollDragOffsetY = y - b.scrollThumb.y
        return true
      end

      if b.scrollThumb and b.scrollMax and b.scrollMax > 0 then
        local minY = b.scrollTrack.y
        local maxY = b.scrollTrack.y + b.scrollTrack.h - b.scrollThumb.h
        local ty = y - b.scrollThumb.h * 0.5
        if ty < minY then
          ty = minY
        elseif ty > maxY then
          ty = maxY
        end
        local t = (maxY > minY) and ((ty - minY) / (maxY - minY)) or 0
        self.scrollRow = math.floor(t * b.scrollMax + 0.5)
        recomputeRects(ctx, displayCols, displayRows)
      end

      return true
    end

    if not self.open then
      return true
    end

    local idx = pickSlot(x, y)
    if not idx then
      return true
    end

    if self.drag and self.drag.id and (self.drag.volume or 0) > 0 then
      return true
    end

    local slot = hold.slots[idx]
    if not slot or not slot.id or (slot.volume or 0) <= 0 then
      return true
    end

    self.drag = Inventory.clone(slot)
    self.dragFrom = idx
    return true
  end

  function self.mousereleased(ctx, x, y, button)
    if button ~= 1 then
      return false
    end

    if self.scrollDrag then
      self.scrollDrag = false
      return true
    end

    if not self.drag or not self.drag.id or (self.drag.volume or 0) <= 0 then
      return false
    end

    local ship = ctx and ctx.world and getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return false
    end

    local hold = ship.cargo_hold
    local displayCols = 2
    local displayRows = getDisplayRows(hold, displayCols)
    recomputeRects(ctx, displayCols, displayRows)

    local b = self.bounds
    if not b then
      return false
    end

    local originIdx = self.dragFrom
    local origin = originIdx and hold.slots[originIdx] or nil
    if not origin or Inventory.isEmpty(origin) then
      self.drag = nil
      self.dragFrom = nil
      return true
    end

    if not pointInRect(x, y, b) then
      local dropX = ctx.mouseWorldX
      local dropY = ctx.mouseWorldY
      if dropX == nil or dropY == nil then
        if ship.physics_body and ship.physics_body.body then
          dropX, dropY = ship.physics_body.body:getPosition()
        else
          dropX, dropY = 0, 0
        end
      end

      if spawnPickup(ctx, origin.id, origin.volume, dropX, dropY) then
        Inventory.clear(origin)
        ship.cargo.used = Inventory.totalVolume(hold.slots)
      end

      self.drag = nil
      self.dragFrom = nil
      return true
    end

    local idx = pickSlot(x, y)

    if not idx or not hold.slots[idx] then
      self.drag = nil
      self.dragFrom = nil
      return true
    end

    local dst = hold.slots[idx]

    if idx == originIdx then
      self.drag = nil
      self.dragFrom = nil
      return true
    end

    if Inventory.isEmpty(dst) then
      dst.id = origin.id
      dst.volume = origin.volume
      Inventory.clear(origin)
      self.drag = nil
      self.dragFrom = nil
      ship.cargo.used = Inventory.totalVolume(hold.slots)
      return true
    end

    if dst.id == origin.id then
      Inventory.mergeInto(dst, origin)
      ship.cargo.used = Inventory.totalVolume(hold.slots)
      self.drag = nil
      self.dragFrom = nil
      return true
    end

    Inventory.swap(origin, dst)
    self.drag = nil
    self.dragFrom = nil
    ship.cargo.used = Inventory.totalVolume(hold.slots)
    return true
  end

  function self.keypressed(ctx, key)
    return false
  end

  function self.wheelmoved(ctx, x, y)
    if not self.open or not ctx then
      return false
    end

    local ship = getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return false
    end

    local hold = ship.cargo_hold
    local displayCols = 2
    local displayRows = getDisplayRows(hold, displayCols)
    recomputeRects(ctx, displayCols, displayRows)

    local b = self.bounds
    if not b then
      return false
    end

    local mx, my = love.mouse.getPosition()
    if not pointInRect(mx, my, b) then
      return false
    end

    local maxScroll = b.scrollMax or 0
    if maxScroll <= 0 or not y or y == 0 then
      return true
    end

    local nextRow = self.scrollRow - y
    if nextRow < 0 then
      nextRow = 0
    elseif nextRow > maxScroll then
      nextRow = maxScroll
    end

    if nextRow ~= self.scrollRow then
      self.scrollRow = nextRow
      recomputeRects(ctx, displayCols, displayRows)
    end

    return true
  end

  return self
end

return makeCargoPanel()
