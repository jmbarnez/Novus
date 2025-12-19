local Concord = require("lib.concord")

local InputSystem = Concord.system({
  ships = { "ship_input" },
})

function InputSystem:init(world)
  self.world = world
  self.input = world:getResource("input")
end

function InputSystem:update()
  self.input:update()

  local uiCapture = self.world and self.world:getResource("ui_capture")
  local captured = uiCapture and uiCapture.active

  local thrust = self.input:down("thrust") and 1 or 0
  local strafe = self.input:down("strafe_right") and 1 or 0
  strafe = strafe - (self.input:down("strafe_left") and 1 or 0)
  local brake = self.input:down("brake") and 1 or 0

  for i = 1, self.ships.size do
    local e = self.ships[i]
    e.ship_input.thrust = 0
    e.ship_input.strafe = 0
    e.ship_input.turn = 0
    e.ship_input.brake = 0
  end

  if captured then
    return
  end

  local player = self.world:getResource("player")
  if not player or not player:has("pilot") then
    return
  end

  local ship = player.pilot.ship
  if ship and ship:has("ship_input") then
    ship.ship_input.thrust = thrust
    ship.ship_input.strafe = strafe
    ship.ship_input.brake = brake
  end
end

return InputSystem
