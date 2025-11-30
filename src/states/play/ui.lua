local DefaultSector = require "src.data.default_sector"

local PlayUI = {}

function PlayUI.initUI(state)
    state.world.ui = {
        cargo_open = false,
        cargo_window = nil,
        cargo_drag = { active = false, offset_x = 0, offset_y = 0 },
        hover_target = nil,
        map_open = false,
        map_window = nil,
        map_drag = { active = false, offset_x = 0, offset_y = 0 },
    }
end

function PlayUI.updateHover(state, dt)
    if not (state.world and state.world.camera and state.world.ui) then return end

    state._hoverAccumulator = (state._hoverAccumulator or 0) + dt
    if state._hoverAccumulator < 0.05 then
        return
    end
    state._hoverAccumulator = 0

    local mx, my = love.mouse.getPosition()
    local wx, wy = state.world.camera:worldCoords(mx, my)
    
    local ship = state.world.local_ship
    local ship_sx = (ship and ship.sector and ship.sector.x) or 0
    local ship_sy = (ship and ship.sector and ship.sector.y) or 0

    local best, bestDist2
    for _, e in ipairs(state.world:getEntities()) do
        if (e.asteroid or e.asteroid_chunk or e.vehicle or e.station or e.item) and e.transform and e.render then
            local sx, sy = (e.sector and e.sector.x or 0), (e.sector and e.sector.y or 0)
            
            if math.abs(sx - ship_sx) <= 1 and math.abs(sy - ship_sy) <= 1 then
                local ex = e.transform.x + (sx - ship_sx) * DefaultSector.SECTOR_SIZE
                local ey = e.transform.y + (sy - ship_sy) * DefaultSector.SECTOR_SIZE
                local dx, dy = wx - ex, wy - ey
                local dist2 = dx*dx + dy*dy
                local baseRadius = e.render.radius or 16
                local r = baseRadius * 1.2
                
                if dist2 <= r*r and (not bestDist2 or dist2 < bestDist2) then
                    best = e
                    bestDist2 = dist2
                end
            end
        end
    end
    state.world.ui.hover_target = best
end

return PlayUI
