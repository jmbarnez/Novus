local Concord = require("lib.concord")

local FloatingTextSystem = Concord.system({
  texts = { "floating_text" },
})

function FloatingTextSystem:init(world)
  self.world = world
  self.font = love.graphics.newFont("assets/fonts/Orbitron-Bold.ttf", 14)
end

function FloatingTextSystem:update(dt)
  for i = self.texts.size, 1, -1 do
    local e = self.texts[i]
    local c = e.floating_text

    c.t = c.t - dt
    if c.t <= 0 then
      e:destroy()
    else
      c.vx = c.vx + (c.ax or 0) * dt
      c.vy = c.vy + (c.ay or 0) * dt

      c.x = c.x + c.vx * dt
      c.y = c.y + c.vy * dt
    end
  end
end

local function computeAlpha(c)
  local a = 1
  if c.color and c.color[4] ~= nil then
    a = c.color[4]
  end

  if c.duration and c.duration > 0 and c.fadeOutFrac and c.fadeOutFrac > 0 then
    local lifeFrac = c.t / c.duration
    if lifeFrac < c.fadeOutFrac then
      a = a * math.max(0, math.min(1, lifeFrac / c.fadeOutFrac))
    end
  end

  return a
end

function FloatingTextSystem:drawWorld()
  local prevFont = love.graphics.getFont()
  if self.font then
    love.graphics.setFont(self.font)
  end

  for i = 1, self.texts.size do
    local e = self.texts[i]
    local c = e.floating_text

    local text = c.text or ""
    local x, y = c.x or 0, c.y or 0
    local scale = c.scale or 1

    local w = self.font and self.font:getWidth(text) or 0
    local h = self.font and self.font:getHeight() or 0

    local a = computeAlpha(c)
    if a > 0 then
      local col = c.color or { 1, 1, 1, 1 }
      local r, g, b = col[1] or 1, col[2] or 1, col[3] or 1

      local shadowEnabled = (c.shadow == nil) and true or not not c.shadow
      if shadowEnabled then
        local sox = c.shadowOffsetX or 1
        local soy = c.shadowOffsetY or 1
        love.graphics.setColor(0, 0, 0, 0.85 * a)
        love.graphics.push()
        love.graphics.translate(x + sox, y + soy)
        love.graphics.scale(scale)
        love.graphics.print(text, -w / 2, -h / 2)
        love.graphics.pop()
      end

      love.graphics.setColor(r, g, b, a)
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.scale(scale)
      love.graphics.print(text, -w / 2, -h / 2)
      love.graphics.pop()
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(prevFont)
end

function FloatingTextSystem:draw()
  return self:drawWorld()
end

return FloatingTextSystem
