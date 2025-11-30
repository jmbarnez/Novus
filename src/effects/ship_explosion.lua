local Concord = require "lib.concord.concord"

local ShipExplosion = {}

function ShipExplosion.spawn(world, ship)
    if not (world and ship and ship.transform and ship.sector) then
        return
    end

    local x = ship.transform.x or 0
    local y = ship.transform.y or 0
    local sx = ship.sector.x or 0
    local sy = ship.sector.y or 0

    local radius = 16
    if ship.render and ship.render.radius then
        radius = ship.render.radius
    end

    local color = { 1.0, 0.75, 0.35, 1.0 }
    if ship.render and ship.render.color then
        color = {
            ship.render.color[1] or 1.0,
            ship.render.color[2] or 0.75,
            ship.render.color[3] or 0.35,
            1.0,
        }
    end

    local e = Concord.entity(world)
    e:give("transform", x, y, 0)
    e:give("sector", sx, sy)
    e:give("render", {
        type = "ship_explosion",
        color = color,
        radius = radius * 1.4,
    })
    e:give("explosion")
    e:give("lifetime", 0.6)

    return e
end

return ShipExplosion
