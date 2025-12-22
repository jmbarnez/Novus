local Concord = require("lib.concord")

local Utils = require("ecs.systems.draw.render_utils")
local ShipDraw = require("ecs.systems.draw.ship_draw")
local AsteroidDraw = require("ecs.systems.draw.asteroid_draw")
local ProjectileDraw = require("ecs.systems.draw.projectile_draw")
local PickupDraw = require("ecs.systems.draw.pickup_draw")
local ShatterDraw = require("ecs.systems.draw.shatter_draw")
local MapUiDraw = require("ecs.systems.draw.map_ui_draw")
local SpaceStationDraw = require("ecs.systems.draw.space_station_draw")
local RefineryStationDraw = require("ecs.systems.draw.refinery_station_draw")

local RenderSystem = Concord.system({
  renderables = { "physics_body", "renderable" },
})

function RenderSystem:init(world)
  self.world = world
end

function RenderSystem:drawWorld()
  love.graphics.setLineWidth(2)

  local playerShip = nil
  if self.world then
    local player = self.world:getResource("player")
    if player and player:has("pilot") and player.pilot.ship then
      playerShip = player.pilot.ship
    end
  end

  local mapUi = self.world and self.world.getResource and self.world:getResource("map_ui")
  MapUiDraw.draw(mapUi)

  local view = self.world and self.world.getResource and self.world:getResource("camera_view")
  local alpha = self.world and self.world.getResource and self.world:getResource("render_alpha")
  local targeting = self.world and self.world.getResource and self.world:getResource("targeting")
  local hovered = targeting and targeting.hovered or nil
  local selected = targeting and targeting.selected or nil
  if alpha == nil then
    alpha = 1
  end
  if alpha < 0 then
    alpha = 0
  elseif alpha > 1 then
    alpha = 1
  end

  local viewLeft, viewTop, viewRight, viewBottom
  if view then
    viewLeft = view.camX
    viewTop = view.camY
    viewRight = view.camX + view.viewW
    viewBottom = view.camY + view.viewH
  end

  local cullPad = 140

  local ctx = {
    playerShip = playerShip,
    hovered = hovered,
    selected = selected,
    cullPad = cullPad,
    viewLeft = viewLeft,
    viewRight = viewRight,
    viewTop = viewTop,
    viewBottom = viewBottom,
  }

  for i = 1, self.renderables.size do
    local e = self.renderables[i]

    local pb = e.physics_body
    local body = pb.body
    local shape = pb.shape

    local x, y = body:getPosition()
    local angle = body:getAngle()
    if pb.prevX ~= nil and pb.prevY ~= nil and pb.prevA ~= nil and alpha ~= 1 then
      x = Utils.lerp(pb.prevX, x, alpha)
      y = Utils.lerp(pb.prevY, y, alpha)
      angle = Utils.lerpAngle(pb.prevA, angle, alpha)
    end

    if e.renderable.kind == "ship" then
      ShipDraw.draw(ctx, e, body, shape, x, y, angle)
    elseif e.renderable.kind == "asteroid" then
      AsteroidDraw.draw(ctx, e, body, shape, x, y, angle)
    elseif e.renderable.kind == "projectile" then
      ProjectileDraw.draw(ctx, e, body, x, y)
    elseif e.renderable.kind == "pickup" then
      PickupDraw.draw(ctx, e, body, x, y)
    elseif e.renderable.kind == "shatter" and e:has("shatter") then
      ShatterDraw.draw(e, body, x, y)
    elseif e.renderable.kind == "space_station" then
      SpaceStationDraw.draw(ctx, e, body, shape, x, y, angle)
    elseif e.renderable.kind == "refinery_station" then
      RefineryStationDraw.draw(ctx, e, body, shape, x, y, angle)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function RenderSystem:draw()
  return self:drawWorld()
end

return RenderSystem
