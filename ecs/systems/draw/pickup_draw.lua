local Utils = require("ecs.systems.draw.render_utils")
local Items = require("game.items")
local ItemIcons = require("game.item_icons")

local PickupDraw = {}

function PickupDraw.draw(ctx, e, body, x, y)
  -- x, y are interpolated positions passed from RenderSystem

  if e:has("pickup") and e.pickup and e.pickup.id then
    local def = Items.get(e.pickup.id)
    if def and def.icon then
      local r0, g0, b0, a0 = e.renderable.color[1], e.renderable.color[2], e.renderable.color[3], e.renderable.color[4]
      local r, g, b, a = Utils.applyFlashToColor(e, r0, g0, b0, a0)
      ItemIcons.drawCentered(e.pickup.id, x, y, 14, { color = { r, g, b, a } })
      return
    end
  end

  Utils.applyFlashColor(e)
  love.graphics.circle("fill", x, y, 6)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.circle("line", x, y, 6)
  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.circle("line", x - 1, y - 1, 4)
end

return PickupDraw
