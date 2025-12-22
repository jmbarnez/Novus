local Gamestate = require("lib.hump.gamestate")
local baton = require("lib.baton")
local Concord = require("lib.concord")

require("ecs.components")

local Systems = require("ecs.systems")
local factory = require("game.factory")
local SpaceBackground = require("game.backgrounds.space_background")
local Camera = require("game.camera")
local Profiler = require("util.profiler")
local Seed = require("util.seed")
local Pause = require("states.pause")
local MathUtil = require("util.math")

local function getInterpolatedTarget(ship, alpha)
  local shipBody = ship and ship.physics_body and ship.physics_body.body
  if not shipBody then
    return nil, nil
  end

  local x, y = shipBody:getPosition()
  local pb = ship.physics_body
  if pb and pb.prevX ~= nil and pb.prevY ~= nil and alpha ~= nil and alpha ~= 1 then
    x = MathUtil.lerp(pb.prevX, x, alpha)
    y = MathUtil.lerp(pb.prevY, y, alpha)
  end

  return x, y
end

local Space = {}

function Space:init()
  -- Fixed timestep improves stability/consistency for Box2D and ship controls.
  self.fixedDt = 1 / 60
end

function Space:enter(_, worldSeed)
  local Settings = require("game.settings")
  self.accumulator = 0
  -- Box2D callbacks can occur during physics stepping; we buffer contacts and emit
  -- ECS events after the step to avoid mutating entities mid-step.
  self.pendingContacts = {}

  self.mouseWorld = { x = 0, y = 0 }

  love.mouse.setVisible(false)

  self.showBackground = true
  self.worldSeed = Seed.normalize(worldSeed or love.math.random(1, 2147483646))
  self.worldRngs = {
    background = love.math.newRandomGenerator(Seed.derive(self.worldSeed, "background")),
    asteroids = love.math.newRandomGenerator(Seed.derive(self.worldSeed, "asteroids")),
  }
  self.background = SpaceBackground.new({
    seed = Seed.derive(self.worldSeed, "starfield"),
    nebulaSeed = Seed.derive(
      self.worldSeed, "nebula")
  })

  self.view = {}
  self.profiler = Profiler.new()

  self.sectorWidth = 10000
  self.sectorHeight = 10000

  self.camera = Camera.new({
    zoom = 1.0,
    minZoom = 0.5,
    maxZoom = 2.0,
    boundsW = self.sectorWidth,
    boundsH = self.sectorHeight,
  })

  local InputConfig = require("game.input_config")
  self.input = baton.new(InputConfig)

  self.physicsWorld = love.physics.newWorld(0, 0, true)
  self.physicsWorld:setCallbacks(
    function(a, b, contact) self:_beginContact(a, b, contact) end,
    function(a, b, contact) self:_endContact(a, b, contact) end
  )

  self.ecsWorld = Concord.world()
  self.ecsWorld:setResource("input", self.input)
  self.ecsWorld:setResource("sector", { width = self.sectorWidth, height = self.sectorHeight })
  self.ecsWorld:setResource("physics", self.physicsWorld)
  self.ecsWorld:setResource("mouse_world", self.mouseWorld)
  self.ecsWorld:setResource("ui_capture", { active = false })
  self.ecsWorld:setResource("map_ui",
    { open = false, zoom = 1.0, centerX = nil, centerY = nil, waypointX = nil, waypointY = nil })
  self.ecsWorld:setResource("world_seed", self.worldSeed)
  self.ecsWorld:setResource("world_rngs", self.worldRngs)
  self.ecsWorld:setResource("station_ui", require("game.station_ui").new())
  self.ecsWorld:setResource("refinery_ui", require("game.refinery_ui").new())

  self.ecsWorld:addSystems(
    Systems.PhysicsSnapshotSystem,
    Systems.InputSystem,
    Systems.TargetingSystem,
    Systems.ShipControlSystem,
    Systems.ContactFlashSystem,
    Systems.ProjectileHitSystem,
    Systems.HitFlashSystem,
    Systems.EngineTrailSystem,
    Systems.WeaponSystem,
    Systems.HealthSystem,
    Systems.ProjectileSystem,
    Systems.PickupSystem,
    Systems.MagnetSystem,
    Systems.ShatterSystem,
    Systems.RenderSystem,
    Systems.FloatingTextSystem,
    Systems.HudSystem,
    Systems.QuestSystem
  )

  self.ecsWorld.__profiler = self.profiler.concord

  -- Assign profile names to all registered systems
  for name, systemClass in pairs(Systems) do
    local s = self.ecsWorld:getSystem(systemClass)
    if s then s.__profileName = name end
  end

  self.hudSystem = self.ecsWorld:getSystem(Systems.HudSystem)

  factory.createWalls(self.physicsWorld, self.sectorWidth, self.sectorHeight)

  -- Create the main hub space station at sector center
  self.spaceStation = factory.createSpaceStation(
    self.ecsWorld,
    self.physicsWorld,
    self.sectorWidth / 2,
    self.sectorHeight / 2,
    "hub"
  )

  -- Create the refinery station offset from the hub
  self.refineryStation = factory.createRefineryStation(
    self.ecsWorld,
    self.physicsWorld,
    self.sectorWidth / 2 + 1500,
    self.sectorHeight / 2 - 800
  )

  -- Spawn the player ship offset from the station
  self.ship = factory.createShip(self.ecsWorld, self.physicsWorld, self.sectorWidth / 2 + 650, self.sectorHeight / 2)
  self.player = factory.createPlayer(self.ecsWorld, self.ship)
  self.ecsWorld:setResource("player", self.player)

  local shipBody = self.ship.physics_body and self.ship.physics_body.body
  local avoidX, avoidY = shipBody:getPosition()
  factory.spawnAsteroids(self.ecsWorld, self.physicsWorld, 70, self.sectorWidth, self.sectorHeight, avoidX, avoidY, 650,
    self.worldRngs.asteroids)
end

function Space:resume()
  if self.input then
    local InputConfig = require("game.input_config")
    -- HACK: Clear cached require to force reload of config which reads Settings
    package.loaded["game.input_config"] = nil
    InputConfig = require("game.input_config")

    -- Creating new baton instance with fresh controls
    local baton = require("lib.baton")
    self.input = baton.new(InputConfig)

    if self.ecsWorld then
      self.ecsWorld:setResource("input", self.input)
    end
  end
end

function Space:_beginContact(fixtureA, fixtureB, contact)
  local a = fixtureA:getUserData()
  local b = fixtureB:getUserData()

  if a == nil and b == nil then
    return
  end

  self.pendingContacts[#self.pendingContacts + 1] = { a = a, b = b, contact = contact }
end

function Space:_endContact(fixtureA, fixtureB, contact)
end

function Space:_drainContacts()
  if #self.pendingContacts == 0 then
    return
  end

  for i = 1, #self.pendingContacts do
    local c = self.pendingContacts[i]
    self.ecsWorld:emit("onContact", c.a, c.b, c.contact)
  end

  self.pendingContacts = {}
end

function Space:update(dt)
  if self.profiler then
    self.profiler:beginFrame()
  end

  local maxFrameDt = 0.10
  if dt > maxFrameDt then
    dt = maxFrameDt
  end

  -- Check if we are docked
  local stationUI = self.ecsWorld and self.ecsWorld:getResource("station_ui")
  local isDocked = stationUI and stationUI.open

  if not isDocked and self.background then
    self.background:update(dt)
  end

  do
    local screenW, screenH = love.graphics.getDimensions()
    local pilotedShip = self.ship
    if self.player and self.player.pilot and self.player.pilot.ship then
      pilotedShip = self.player.pilot.ship
    end

    local shipBody = pilotedShip and pilotedShip.physics_body and pilotedShip.physics_body.body
    if shipBody then
      local targetX, targetY = shipBody:getPosition()
      local view = self.camera:getView(screenW, screenH, targetX, targetY, self.view)
      local mx, my = love.mouse.getPosition()
      self.mouseWorld.x = (mx / view.zoom) + view.camX
      self.mouseWorld.y = (my / view.zoom) + view.camY
    end
  end

  if not isDocked then
    do
      local t0 = love.timer.getTime()
      self.ecsWorld:emit("update", dt)
      if self.profiler then
        self.profiler:add("ecs:update", (love.timer.getTime() - t0) * 1000)
      end
    end

    local maxSubSteps = 6
    local maxAccum = self.fixedDt * maxSubSteps
    self.accumulator = math.min(self.accumulator + dt, maxAccum)

    local steps = 0
    while self.accumulator >= self.fixedDt and steps < maxSubSteps do
      local t0 = love.timer.getTime()
      self.ecsWorld:emit("fixedUpdate", self.fixedDt)
      self.physicsWorld:update(self.fixedDt)
      if self.profiler then
        self.profiler:add("fixed+physics", (love.timer.getTime() - t0) * 1000)
      end
      self:_drainContacts()
      self.accumulator = self.accumulator - self.fixedDt
      steps = steps + 1
    end

    if self.ecsWorld and self.fixedDt > 0 then
      self.ecsWorld:setResource("render_alpha", self.accumulator / self.fixedDt)
    end
  end
end

function Space:draw()
  love.graphics.clear(0.02, 0.04, 0.08, 1)

  local screenW, screenH = love.graphics.getDimensions()
  local pilotedShip = self.ship
  if self.player and self.player.pilot and self.player.pilot.ship then
    pilotedShip = self.player.pilot.ship
  end

  local alpha = self.ecsWorld and self.ecsWorld.getResource and self.ecsWorld:getResource("render_alpha")
  if alpha == nil then
    alpha = 1
  end
  alpha = MathUtil.clamp(alpha, 0, 1)

  local targetX, targetY = getInterpolatedTarget(pilotedShip, alpha)

  local view = self.camera:getView(screenW, screenH, targetX, targetY, self.view)
  if self.ecsWorld then
    self.ecsWorld:setResource("camera_view", view)
  end

  if self.showBackground and self.background then
    local t0 = love.timer.getTime()
    self.background:draw(view.focusX, view.focusY)
    if self.profiler then
      self.profiler:add("background:draw", (love.timer.getTime() - t0) * 1000)
    end
  end

  love.graphics.push()
  love.graphics.scale(view.zoom)
  love.graphics.translate(-view.camX, -view.camY)
  love.graphics.setColor(0.25, 0.35, 0.55, 0.6)
  love.graphics.rectangle("line", 0, 0, self.sectorWidth, self.sectorHeight)
  love.graphics.setColor(1, 1, 1, 1)
  do
    local t0 = love.timer.getTime()
    self.ecsWorld:emit("drawWorld")
    if self.profiler then
      self.profiler:add("ecs:drawWorld", (love.timer.getTime() - t0) * 1000)
    end
  end
  love.graphics.pop()

  do
    local t0 = love.timer.getTime()
    self.ecsWorld:emit("drawHud")
    if self.profiler then
      self.profiler:add("ecs:drawHud", (love.timer.getTime() - t0) * 1000)
    end
  end

  if self.profiler then
    self.profiler:endFrame()
    self.profiler:drawOverlay(12, 12)
  end
end

function Space:keypressed(key)
  local uiCapture = self.ecsWorld and self.ecsWorld:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    if self.hudSystem then
      self.hudSystem:keypressed(key)
    end
    return
  end

  if key == "escape" then
    Gamestate.push(Pause)
  elseif key == "f1" and self.profiler then
    self.profiler:setEnabled(not self.profiler.enabled)
  elseif key == "f2" then
    local getVsync = love.window and love.window.getVSync
    local setVsync = love.window and love.window.setVSync
    if setVsync then
      local cur = (getVsync and getVsync()) or 0
      setVsync(cur == 0 and 1 or 0)
    end
  elseif key == "f11" then
    local isFullscreen = love.window.getFullscreen()
    love.window.setFullscreen(not isFullscreen)
  elseif self.hudSystem and self.hudSystem:keypressed(key) then
    return
  elseif key == "b" then
    self.showBackground = not self.showBackground
  elseif key == "=" or key == "kp+" then
    if self.camera then
      self.camera:zoomIn()
    end
  elseif key == "-" or key == "kp-" then
    if self.camera then
      self.camera:zoomOut()
    end
  elseif key == "r" then
    Gamestate.switch(Space, self.worldSeed)
  end
end

function Space:wheelmoved(x, y)
  if y == 0 then
    return
  end

  local uiCapture = self.ecsWorld and self.ecsWorld:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    if self.hudSystem then
      self.hudSystem:wheelmoved(x, y)
    end
    return
  end

  if self.hudSystem and self.hudSystem:wheelmoved(x, y) then
    return
  end

  if not self.camera then
    return
  end

  if y > 0 then
    self.camera:zoomIn()
  else
    self.camera:zoomOut()
  end
end

function Space:mousepressed(x, y, button)
  if not self.camera or not self.ecsWorld then
    return
  end

  local uiCapture = self.ecsWorld:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    if self.hudSystem then
      self.hudSystem:mousepressed(x, y, button)
    end
    return
  end

  if self.hudSystem and self.hudSystem:mousepressed(x, y, button) then
    return
  end

  if button ~= 1 then
    return
  end

  local screenW, screenH = love.graphics.getDimensions()

  local pilotedShip = self.ship
  local player = self.ecsWorld:getResource("player")
  if player and player.pilot and player.pilot.ship then
    pilotedShip = player.pilot.ship
  end

  local alpha = self.ecsWorld and self.ecsWorld.getResource and self.ecsWorld:getResource("render_alpha")
  if alpha == nil then
    alpha = 1
  end
  alpha = MathUtil.clamp(alpha, 0, 1)

  local targetX, targetY = getInterpolatedTarget(pilotedShip, alpha)

  local view = self.camera:getView(screenW, screenH, targetX, targetY, self.view)
  local worldX = (x / view.zoom) + view.camX
  local worldY = (y / view.zoom) + view.camY

  self.ecsWorld:emit("onTargetClick", worldX, worldY, button)
end

function Space:mousereleased(x, y, button)
  if self.hudSystem then
    self.hudSystem:mousereleased(x, y, button)
  end
end

function Space:mousemoved(x, y, dx, dy)
  if self.hudSystem then
    self.hudSystem:mousemoved(x, y, dx, dy)
  end
end

function Space:leave()
  love.mouse.setVisible(true)
end

return Space
