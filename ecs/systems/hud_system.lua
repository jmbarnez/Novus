local Concord = require("lib.concord")
local Hud = require("game.hud.hud")
local HudContext = require("game.hud.context")

local HudSystem = Concord.system({
  ships = { "ship", "physics_body" },
})

function HudSystem:init(world)
  self.world = world
  self.hud = Hud.default()
  self.hudFont = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 12)
end

function HudSystem:_buildCtx()
  local ctx = HudContext.build(self.world, self.ships)
  ctx.hud = self.hud -- Allow widgets to access hud for focus management
  return ctx
end

function HudSystem:_setCapture(active)
  local uiCapture = self.world and self.world:getResource("ui_capture")
  if uiCapture then
    uiCapture.active = active and true or false
  end
end

function HudSystem:isCapturing()
  local uiCapture = self.world and self.world:getResource("ui_capture")
  return uiCapture and uiCapture.active or false
end

function HudSystem:drawHud()
  local ctx = self:_buildCtx()

  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  self.hud:draw(ctx)
  love.graphics.setFont(prevFont)
end

function HudSystem:mousepressed(x, y, button)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:mousepressed(ctx, x, y, button)
  love.graphics.setFont(prevFont)

  if consumed then
    self:_setCapture(true)
  end
  return consumed
end

function HudSystem:mousereleased(x, y, button)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:mousereleased(ctx, x, y, button)
  love.graphics.setFont(prevFont)

  self:_setCapture(false)
  return consumed
end

function HudSystem:mousemoved(x, y, dx, dy)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:mousemoved(ctx, x, y, dx, dy)
  love.graphics.setFont(prevFont)
  return consumed or self:isCapturing()
end

function HudSystem:wheelmoved(x, y)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:wheelmoved(ctx, x, y)
  love.graphics.setFont(prevFont)
  return consumed or self:isCapturing()
end

function HudSystem:keypressed(key)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:keypressed(ctx, key)
  love.graphics.setFont(prevFont)
  return consumed or self:isCapturing()
end

function HudSystem:textinput(text)
  local ctx = self:_buildCtx()
  local prevFont = love.graphics.getFont()
  if self.hudFont then
    love.graphics.setFont(self.hudFont)
  end
  local consumed = self.hud:textinput(ctx, text)
  love.graphics.setFont(prevFont)
  return consumed or self:isCapturing()
end

function HudSystem:draw()
  return self:drawHud()
end

return HudSystem
