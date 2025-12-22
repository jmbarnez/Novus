--- Cargo Panel HUD Widget
--- Uses cargo_panel_view and cargo_panel_draw for layout and drawing

local Theme = require("game.theme")
local Inventory = require("game.inventory")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local PickupFactory = require("game.factory.pickup")
local CargoView = require("game.hud.widgets.cargo_panel.view")
local CargoDraw = require("game.hud.widgets.cargo_panel.draw")

local pointInRect = Rect.pointInRect

local function spawnPickup(ctx, id, volume, worldX, worldY)
  if not ctx or not ctx.world or not id or not volume or volume <= 0 then
    return false
  end

  local physicsWorld = ctx.world:getResource("physics")
  if not physicsWorld then
    return false
  end

  local e = PickupFactory.spawn(ctx.world, physicsWorld, id, worldX or 0, worldY or 0, volume)
  return e ~= nil
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

  -- State helpers --------------------------------------------------------
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
    local bounds, slotRects, fx, fy = CargoView.computeLayout(ctx, self.frame, self.frame.x, self.frame.y)
    self.bounds = bounds
    self.slotRects = slotRects
    if self.frame.x == nil then self.frame.x = fx end
    if self.frame.y == nil then self.frame.y = fy end
  end

  -- Interface: hitTest ---------------------------------------------------
  function self.hitTest(ctx, x, y)
    if not ctx or not self.open then
      return false
    end

    recomputeRects(ctx)

    local b = self.bounds
    if not b then
      return false
    end

    return pointInRect(x, y, b)
  end

  -- Interface: draw ------------------------------------------------------
  function self.draw(ctx)
    if not ctx or not self.open then
      return
    end

    setCapture(ctx)

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local ship = CargoView.getPlayerShip(ctx.world)
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

    local cp = hudTheme.cargoPanel or {}
    self.frame:draw(ctx, b, { title = cp.title or "CARGO", titlePad = b.pad })

    local mx, my = love.mouse.getPosition()
    local hoverIdx = CargoView.pickSlot(self.slotRects, mx, my, self.open)

    CargoDraw.drawSlots(b, self.slotRects, hold, hoverIdx, self.dragFrom)
    CargoDraw.drawDragItem(self.drag, b.slot or 44)
    CargoDraw.drawFooterBar(ctx, b, cargo.used or 0, cargo.capacity or 0)

    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Interface: mousepressed ----------------------------------------------
  function self.mousepressed(ctx, x, y, button)
    if not self.open then
      return false
    end

    setCapture(ctx)

    local ship = ctx and ctx.world and CargoView.getPlayerShip(ctx.world)
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

    local idx = CargoView.pickSlot(self.slotRects, x, y, self.open)
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

  -- Interface: mousereleased ---------------------------------------------
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

    local ship = ctx and ctx.world and CargoView.getPlayerShip(ctx.world)
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

    local idx = CargoView.pickSlot(self.slotRects, x, y, self.open)

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

  -- Interface: keypressed ------------------------------------------------
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

  -- Interface: wheelmoved ------------------------------------------------
  function self.wheelmoved(ctx, x, y)
    if not self.open or not ctx then
      return false
    end

    setCapture(ctx)
    return true
  end

  -- Interface: mousemoved ------------------------------------------------
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
