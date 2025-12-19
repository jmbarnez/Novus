local Hud = {}
Hud.__index = Hud

function Hud.new(widgets)
  local self = setmetatable({}, Hud)
  self.widgets = widgets or {}
  return self
end

function Hud:mousemoved(ctx, x, y, dx, dy)
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
  for i = 1, #self.widgets do
    local w = self.widgets[i]
    if w and w.draw then
      w.draw(ctx)
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
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.mousepressed then
      if w.mousepressed(ctx, x, y, button) then
        return true
      end
    end
  end
  return false
end

function Hud:mousereleased(ctx, x, y, button)
  for i = #self.widgets, 1, -1 do
    local w = self.widgets[i]
    if w and w.mousereleased then
      if w.mousereleased(ctx, x, y, button) then
        return true
      end
    end
  end
  return false
end

function Hud:keypressed(ctx, key)
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

function Hud:wheelmoved(ctx, x, y)
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
    require("game.hud.widgets.cargo_panel_bottom_right"),
    require("game.hud.widgets.minimap_top_right"),
    require("game.hud.widgets.fps_top_right"),
    require("game.hud.widgets.target_panel_top_center"),
    require("game.hud.widgets.cursor_reticle"),
    require("game.hud.widgets.cursor_cooldown"),
    require("game.hud.widgets.waypoint_indicator"),
    require("game.hud.widgets.fullscreen_map"),
  })
end

return Hud
