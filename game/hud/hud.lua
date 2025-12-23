local Hud = {}
Hud.__index = Hud

function Hud.new(widgets)
  local self = setmetatable({}, Hud)
  self.widgets = widgets or {}
  self.focusedWidget = nil -- Track which widget is focused (should be drawn on top)
  return self
end

-- Bring a widget to front (draw on top)
function Hud:bringToFront(widget)
  self.focusedWidget = widget
end

-- Returns widgets in input priority (topmost -> bottom) matching draw order
function Hud:_inputOrder()
  local order = {}
  local numWidgets = #self.widgets
  local alwaysOnTopWidget = self.widgets[numWidgets]

  if self.focusedWidget and self.focusedWidget ~= alwaysOnTopWidget then
    order[#order + 1] = self.focusedWidget
  end

  for i = numWidgets, 1, -1 do
    local w = self.widgets[i]
    if w and w ~= self.focusedWidget and w ~= alwaysOnTopWidget then
      order[#order + 1] = w
    end
  end

  if alwaysOnTopWidget then
    order[#order + 1] = alwaysOnTopWidget
  end

  return order
end

function Hud:mousemoved(ctx, x, y, dx, dy)
  -- Check all widgets - whichever consumes input wins
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.mousemoved then
      if w.mousemoved(ctx, x, y, dx, dy) then
        return true
      end
    end
  end
  return false
end

function Hud:draw(ctx)
  local mx, my = love.mouse.getPosition()
  if ctx then
    ctx.uiOverHud = false
    ctx.hoverWidget = nil
  end

  local numWidgets = #self.widgets
  local alwaysOnTopWidget = self.widgets[numWidgets] -- Last widget (cursor_reticle) always on top

  -- Pre-pass: find the topmost widget under the cursor in draw order
  if ctx then
    local function testHover(w)
      if w and w.hitTest and w.hitTest(ctx, mx, my) then
        ctx.hoverWidget = w
      end
    end

    for i = 1, numWidgets do
      local w = self.widgets[i]
      if w ~= self.focusedWidget and w ~= alwaysOnTopWidget then
        testHover(w)
      end
    end

    if self.focusedWidget and self.focusedWidget ~= alwaysOnTopWidget then
      testHover(self.focusedWidget)
    end

    if alwaysOnTopWidget then
      testHover(alwaysOnTopWidget)
    end

    if ctx.hoverWidget then
      ctx.uiOverHud = true
    end
  end

  -- Draw all widgets except the focused one and the always-on-top widget first
  for i = 1, numWidgets do
    local w = self.widgets[i]
    if w ~= self.focusedWidget and w ~= alwaysOnTopWidget then
      if w and w.draw then
        w.draw(ctx)
      end
    end
  end

  -- Draw focused widget (on top of others, but below cursor)
  if self.focusedWidget and self.focusedWidget ~= alwaysOnTopWidget then
    local w = self.focusedWidget
    if w.draw then
      w.draw(ctx)
    end
  end

  -- Draw the always-on-top widget (cursor) absolutely last
  if alwaysOnTopWidget then
    if alwaysOnTopWidget.draw then
      alwaysOnTopWidget.draw(ctx)
    end
  end
end

function Hud:layout(ctx)
  for i = 1, #self.widgets do
    local w = self.widgets[i]
    if w and w.layout then
      w.layout(ctx)
    end
  end
end

function Hud:mousepressed(ctx, x, y, button)
  -- Check widgets from topmost to bottom to mirror draw order
  local order = self:_inputOrder()
  for i = 1, #order do
    local w = order[i]
    if w and w.mousepressed then
      if w.mousepressed(ctx, x, y, button) then
        if w ~= self.widgets[#self.widgets] then
          self:bringToFront(w)
        end
        return true
      end
    end
  end
  return false
end

function Hud:mousereleased(ctx, x, y, button)
  local order = self:_inputOrder()
  for i = 1, #order do
    local w = order[i]
    if w and w.mousereleased then
      if w.mousereleased(ctx, x, y, button) then
        return true
      end
    end
  end
  return false
end

function Hud:keypressed(ctx, key)
  -- Check all widgets
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.keypressed then
      if w.keypressed(ctx, key) then
        return true
      end
    end
  end
  return false
end

function Hud:textinput(ctx, text)
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.textinput then
      if w.textinput(ctx, text) then
        return true
      end
    end
  end
  return false
end

function Hud:wheelmoved(ctx, x, y)
  -- Check all widgets
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.wheelmoved then
      if w.wheelmoved(ctx, x, y) then
        return true
      end
    end
  end
  return false
end

function Hud.default()
  return Hud.new({
    require("game.hud.widgets.status_panel_top_left"),
    require("game.hud.widgets.controls_bottom_left"),
    require("game.hud.widgets.cargo_panel"),
    require("game.hud.widgets.fps_top_right"),
    require("game.hud.widgets.minimap_top_right"),
    require("game.hud.widgets.active_quest"),
    require("game.hud.widgets.target_panel_top_center"),
    require("game.hud.widgets.cursor_cooldown"),
    require("game.hud.widgets.waypoint_indicator"),
    require("game.hud.widgets.interaction_prompt"),
    require("game.hud.widgets.station_window"),
    require("game.hud.widgets.refinery_window"),
    require("game.hud.widgets.skill_window"),
    require("game.hud.widgets.fullscreen_map"),
    require("game.hud.widgets.cursor_reticle"),
  })
end

return Hud
