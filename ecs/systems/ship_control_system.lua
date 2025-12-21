local Concord = require("lib.concord")
local Math = require("util.math")

local ShipControlSystem = Concord.system({
  ships = { "ship", "ship_input", "ship_control", "physics_body" },
})

local clamp = Math.clamp
local normalizeAngle = Math.normalizeAngle
local atan2 = Math.atan2

function ShipControlSystem:init(world)
  self.world = world
  self.mouseWorld = world:getResource("mouse_world")
end

-- Compute derived control stats from physics properties
function ShipControlSystem:_computeDerivedStats(e)
  local body = e.physics_body.body
  local ctrl = e.ship_control

  local inertia = body:getInertia()

  -- Estimate lever arm from bounding box of shape
  local shape = e.physics_body.shape
  local leverArm = 10 -- default fallback
  if shape and shape.getPoints then
    local ok, pts = pcall(function() return { shape:getPoints() } end)
    if ok and pts then
      local maxR = 0
      for i = 1, #pts, 2 do
        local r = math.sqrt(pts[i] ^ 2 + pts[i + 1] ^ 2)
        if r > maxR then maxR = r end
      end
      if maxR > 0 then leverArm = maxR end
    end
  end

  -- Calculate effective torque: thruster force * lever arm
  ctrl.torque = ctrl.rcsPower * leverArm

  -- Max angular speed: scale inversely with sqrt of inertia
  -- Clamp to reasonable range (1.5 to 4.0 rad/s)
  local rawMaxW = math.sqrt(ctrl.torque / math.max(1, inertia)) * 0.8
  ctrl.maxAngularSpeed = math.max(1.5, math.min(4.0, rawMaxW))

  -- Stabilization torque scales with inertia
  ctrl.stabilizeTorque = inertia * ctrl.stabilization * 3.0

  ctrl._initialized = true
end

function ShipControlSystem:fixedUpdate(dt)
  local player = self.world and self.world:getResource("player")
  local playerShip = player and player:has("pilot") and player.pilot.ship or nil
  local uiCapture = self.world and self.world:getResource("ui_capture")
  local captured = uiCapture and uiCapture.active

  for i = 1, self.ships.size do
    local e = self.ships[i]
    local body = e.physics_body.body

    -- Initialize derived stats on first encounter
    if not e.ship_control._initialized then
      self:_computeDerivedStats(e)
    end

    local angle = body:getAngle()
    local thrustForce = e.ship_control.thrustForce
    local strafeForce = e.ship_control.strafeForce or 0
    local torque = e.ship_control.torque

    local thrust = e.ship_input.thrust
    local fx = math.cos(angle) * thrustForce * thrust
    local fy = math.sin(angle) * thrustForce * thrust

    body:applyForce(fx, fy)

    local brake = e.ship_input.brake or 0
    if brake > 0 then
      local vx, vy = body:getLinearVelocity()
      local speed2 = vx * vx + vy * vy
      if speed2 < 4 then
        body:setLinearVelocity(0, 0)
      else
        local brakeK = 3.0
        local mass = body:getMass()
        body:applyForce(-vx * brakeK * mass, -vy * brakeK * mass)
      end
    end

    local strafe = e.ship_input.strafe or 0
    if strafeForce ~= 0 and strafe ~= 0 then
      local sx = -math.sin(angle) * strafeForce * strafe
      local sy = math.cos(angle) * strafeForce * strafe
      body:applyForce(sx, sy)
    end

    local turn = e.ship_input.turn
    local usedMouseSteer = (not captured) and (playerShip ~= nil and e == playerShip and self.mouseWorld ~= nil)
    if usedMouseSteer then
      local sx, sy = body:getPosition()
      local dx = (self.mouseWorld.x or sx) - sx
      local dy = (self.mouseWorld.y or sy) - sy

      local dist2 = dx * dx + dy * dy
      if dist2 > 0.0001 then
        local desiredAngle = atan2(dy, dx)
        local delta = normalizeAngle(desiredAngle - angle)

        -- PD-ish controller: convert angle error into a desired angular velocity,
        -- then use torque to chase it while respecting maxAngularSpeed.
        local maxW = e.ship_control.maxAngularSpeed or 0
        local desiredW = (maxW and maxW > 0) and clamp(delta * 3.0, -maxW, maxW) or (delta * 3.0)
        local w = body:getAngularVelocity()
        local wErr = desiredW - w
        local turnCmd = clamp(wErr * 0.6, -1, 1)
        body:applyTorque(torque * turnCmd)
      else
        usedMouseSteer = false
      end
    end

    if not usedMouseSteer then
      if turn ~= 0 then
        body:applyTorque(torque * turn)
      else
        local stabilizeTorque = e.ship_control.stabilizeTorque
        if stabilizeTorque ~= 0 then
          local w = body:getAngularVelocity()
          body:applyTorque(-w * stabilizeTorque)
        end
      end
    end

    local maxW = e.ship_control.maxAngularSpeed
    if maxW and maxW > 0 then
      local w = body:getAngularVelocity()
      if w > maxW then
        body:setAngularVelocity(maxW)
      elseif w < -maxW then
        body:setAngularVelocity(-maxW)
      end
    end
  end
end

return ShipControlSystem
