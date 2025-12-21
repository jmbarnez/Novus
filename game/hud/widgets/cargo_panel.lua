local Theme = require("game.theme")
local Items = require("game.items")
local Inventory = require("game.inventory")
local ItemIcons = require("game.item_icons")
local WindowFrame = require("game.hud.window_frame")

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
    open = false,
    frame = WindowFrame.new(),
    bounds = nil,
    slotRects = {},
    drag = nil,
    dragFrom = nil,
  }

  local function getUiCapture(ctx)
    local world = ctx and ctx.world
    return world and world:getResource("ui_capture")
  end

  local function isMapOpen(ctx)
    local world = ctx and ctx.world
    local mapUi = world and world:getResource("map_ui")
    return mapUi and mapUi.open or false
  end

  local function setCapture(ctx)
    local uiCapture = getUiCapture(ctx)
    if uiCapture then
      uiCapture.active = (self.open or isMapOpen(ctx)) and true or false
    end
  end

  local function recomputeRects(ctx)
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

    if self.frame.x == nil or self.frame.y == nil then
      local screenW = ctx and ctx.screenW or 0
      local screenH = ctx and ctx.screenH or 0
      self.frame.x = math.floor((screenW - panelW) * 0.5)
      self.frame.y = math.floor((screenH - panelH) * 0.5)
    end

    local frameBounds = self.frame:compute(ctx, panelW, panelH, {
      margin = margin,
      headerH = headerH,
      footerH = footerH,
      closeSize = cp.closeSize or 18,
      closePad = cp.closePad or 6,
    })

    self.bounds = frameBounds
    self.bounds.pad = pad
    self.bounds.slot = slot
    self.bounds.gap = gap
    self.bounds.footerGap = footerGap
    self.bounds.gridX = frameBounds.x + pad
    self.bounds.gridY = frameBounds.y + pad + headerH
    self.bounds.gridW = gridW
    self.bounds.gridH = gridH
    self.bounds.cols = cols
    self.bounds.rows = rows

    local clearN = cols * rows
    if #self.slotRects > clearN then
      clearN = #self.slotRects
    end
    for i = 1, clearN do
      self.slotRects[i] = nil
    end

    local gridX = frameBounds.x + pad
    local gridY = frameBounds.y + pad + headerH
    local idx = 1
    for r = 1, rows do
      for c = 1, cols do
        local sx = gridX + (c - 1) * (slot + gap)
        local sy = gridY + (r - 1) * (slot + gap)
        local slotIdx = (r - 1) * cols + c
        self.slotRects[idx] = { x = sx, y = sy, w = slot, h = slot, idx = slotIdx }
        idx = idx + 1
      end
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

    if not self.open then
      return false
    end

    recomputeRects(ctx)

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

    if not self.open then
      return
    end

    setCapture(ctx)

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local ship = getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return
    end

    local hold = ship.cargo_hold
    local cargo = ship.cargo

    recomputeRects(ctx)

    local b = self.bounds

    if not b then
      return
    end

    do
      local cp = hudTheme.cargoPanel or {}
      self.frame:draw(ctx, b, { title = cp.title or "CARGO", titlePad = b.pad })
    end

    local used = cargo.used or 0
    local cap = cargo.capacity or 0

    do
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

            if def and def.icon then
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

        if def and def.icon then
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
      local colors = hudTheme.colors
      local footer = b.footerRect
      local barPadX = 10
      local barPadY = 8
      local barX = footer.x + barPadX
      local barW = footer.w - barPadX * 2
      local barH = (hudTheme.cargoPanel and hudTheme.cargoPanel.barH) or 10
      local barY = footer.y + math.floor((footer.h - barH) * 0.5)

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

    love.graphics.setColor(1, 1, 1, 1)
  end

  function self.mousepressed(ctx, x, y, button)
    if not self.open then
      return false
    end

    setCapture(ctx)

    local ship = ctx and ctx.world and getPlayerShip(ctx.world)
    if not ship or not ship.cargo_hold or not ship.cargo then
      return false
    end

    local hold = ship.cargo_hold
    recomputeRects(ctx)

    local b = self.bounds
    if not b then
      return false
    end

    if not pointInRect(x, y, b) then
      return true
    end

    local consumed, didClose, didDrag = self.frame:mousepressed(ctx, b, x, y, button)
    if didClose then
      self.open = false
      self.drag = nil
      self.dragFrom = nil
      self.frame.dragging = false
      setCapture(ctx)
      return true
    end
    if didDrag then
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
    if not self.open then
      return false
    end

    setCapture(ctx)

    if button ~= 1 then
      return false
    end

    if self.frame:mousereleased(ctx, x, y, button) then
      setCapture(ctx)
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
    recomputeRects(ctx)

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
    if key == "tab" then
      self.open = not self.open
      self.drag = nil
      self.dragFrom = nil
      self.frame.dragging = false
      setCapture(ctx)
      return true
    end

    if not self.open then
      return false
    end

    if key == "escape" then
      self.open = false
      self.drag = nil
      self.dragFrom = nil
      self.frame.dragging = false
      setCapture(ctx)
      return true
    end

    return true
  end

  function self.wheelmoved(ctx, x, y)
    if not self.open or not ctx then
      return false
    end

    setCapture(ctx)
    return true
  end

  function self.mousemoved(ctx, x, y, dx, dy)
    if not self.open then
      return false
    end

    if self.frame:mousemoved(ctx, x, y, dx, dy) and ctx then
      recomputeRects(ctx)
      setCapture(ctx)
      return true
    end

    if ctx then
      recomputeRects(ctx)
      local b = self.bounds
      if b and pointInRect(x, y, b) then
        setCapture(ctx)
        return true
      end
    end

    return false
  end

  return self
end

return makeCargoPanel()
