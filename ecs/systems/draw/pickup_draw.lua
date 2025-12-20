local Utils = require("ecs.systems.draw.render_utils")
local ItemIcons = require("game.item_icons")

local PickupDraw = {}

function PickupDraw.draw(ctx, e, body)
  local x, y = body:getPosition()

  if e:has("pickup") and e.pickup and e.pickup.id == "stone" then
    local r0, g0, b0, a0 = e.renderable.color[1], e.renderable.color[2], e.renderable.color[3], e.renderable.color[4]
    local r, g, b, a = Utils.applyFlashToColor(e, r0, g0, b0, a0)
    ItemIcons.drawCentered("stone", x, y, 14, { color = { r, g, b, a } })
  else
    Utils.applyFlashColor(e)
    love.graphics.circle("fill", x, y, 6)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.circle("line", x, y, 6)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("line", x - 1, y - 1, 4)
  end
end

return PickupDraw
