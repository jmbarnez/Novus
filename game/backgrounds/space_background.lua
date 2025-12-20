local SpaceBackground = {}
SpaceBackground.__index = SpaceBackground

local STAR_ALPHA_BOOST = 1.8
local NEBULA_PARALLAX = 0.00015
local NEBULA_TIME_SCALE = 0.1
local NEBULA_SHADER_PATH = "game/shaders/nebula.glsl"
local MathUtil = require("util.math")

local function pickStarColor(rng, parallax)
  local t = rng:random()
  local r, g, b

  if parallax <= 0.00025 then
    if t < 0.85 then
      r, g, b = 0.92, 0.95, 1.00
    else
      r, g, b = 0.70, 0.82, 1.00
    end
  elseif parallax <= 0.0009 then
    if t < 0.70 then
      r, g, b = 0.95, 0.97, 1.00
    elseif t < 0.90 then
      r, g, b = 0.72, 0.85, 1.00
    else
      r, g, b = 1.00, 0.92, 0.75
    end
  else
    if t < 0.55 then
      r, g, b = 0.98, 0.99, 1.00
    elseif t < 0.75 then
      r, g, b = 0.75, 0.88, 1.00
    else
      r, g, b = 1.00, 0.88, 0.65
    end
  end

  local v = 0.90 + 0.10 * rng:random()
  return r * v, g * v, b * v
end

local function buildStarfield(rng, tileW, tileH, density, parallaxMin, parallaxMax, depthPower)
  local stars = {}

  local count = math.floor(tileW * tileH * density)
  for i = 1, count do
    local t = rng:random()
    t = t ^ depthPower

    local parallax = parallaxMin + (parallaxMax - parallaxMin) * t
    local cr, cg, cb = pickStarColor(rng, parallax)
    local b = 0.65 + 0.35 * rng:random()

    local alpha = 0.22 + 0.26 * t
    local size = 1 + (2.6 - 1) * (t * t)
    stars[i] = {
      x = math.floor(rng:random() * tileW),
      y = math.floor(rng:random() * tileH),
      size = size,
      base = b,
      cr = cr,
      cg = cg,
      cb = cb,
      alpha = alpha,
      parallax = parallax,
      twinklePhase = rng:random() * math.pi * 2,
      twinkleSpeed = 0.4 + 1.2 * rng:random(),
    }
  end

  return stars
end

function SpaceBackground.new(opts)
  opts = opts or {}

  local self = setmetatable({}, SpaceBackground)

  local seed = opts.seed or love.math.random(1, 1000000000)
  self.rng = love.math.newRandomGenerator(seed)

  self.time = 0
  self.renderScale = opts.renderScale or 1
  local updateHz = opts.updateHz
  if updateHz == nil then
    updateHz = 0
  end
  self.redrawInterval = (updateHz and updateHz > 0) and (1 / updateHz) or 0
  self.redrawAcc = 0
  self.canvas = nil
  self.canvasW = 0
  self.canvasH = 0
  self.lastFocusX = nil
  self.lastFocusY = nil
  do
    local nebulaSeed = opts.nebulaSeed
    if nebulaSeed == nil then
      nebulaSeed = self.rng:random() * 1000
    elseif type(nebulaSeed) == "number" then
      local a = math.abs(nebulaSeed)
      if a > 10000 then
        local m = 1000000
        nebulaSeed = (nebulaSeed % m) / m * 1000
      end
    end
    self.nebulaSeed = nebulaSeed
  end
  self._shaderResolution = { 0, 0 }
  self._shaderOffset = { 0, 0 }

  do
    local ok, sourceOrErr = pcall(love.filesystem.read, NEBULA_SHADER_PATH)
    if ok and sourceOrErr then
      local okShader, shaderOrErr = pcall(love.graphics.newShader, sourceOrErr)
      if okShader then
        self.nebulaShader = shaderOrErr
      else
        self.nebulaShader = nil
        print("Failed to compile nebula shader: " .. tostring(shaderOrErr))
      end
    else
      self.nebulaShader = nil
      print("Failed to read nebula shader file: " .. tostring(sourceOrErr))
    end
  end

  self.tileW = opts.tileW or 1024
  self.tileH = opts.tileH or 1024
  local density = opts.density or 0.0007
  local parallaxMin = opts.parallaxMin or 0.00002
  local parallaxMax = opts.parallaxMax or 0.0010
  local depthPower = opts.depthPower or 3

  self.stars = buildStarfield(self.rng, self.tileW, self.tileH, density, parallaxMin, parallaxMax, depthPower)

  return self
end

function SpaceBackground:update(dt)
  self.time = self.time + dt
  self.redrawAcc = self.redrawAcc + dt
end

function SpaceBackground:_drawNebula(screenW, screenH, focusX, focusY)
  if not self.nebulaShader then
    return
  end

  love.graphics.push("all")

  self.nebulaShader:send("time", self.time * NEBULA_TIME_SCALE)
  self._shaderResolution[1] = screenW
  self._shaderResolution[2] = screenH
  self.nebulaShader:send("resolution", self._shaderResolution)
  -- focusX/focusY are world-space; we scale them down to create a subtle parallax drift.
  self._shaderOffset[1] = -focusX * NEBULA_PARALLAX
  self._shaderOffset[2] = -focusY * NEBULA_PARALLAX
  self.nebulaShader:send("offset", self._shaderOffset)
  if self.nebulaSeed ~= nil then
    pcall(self.nebulaShader.send, self.nebulaShader, "seed", self.nebulaSeed)
  end

  love.graphics.setShader(self.nebulaShader)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  love.graphics.pop()
end

function SpaceBackground:_drawStars(screenW, screenH, focusX, focusY)
  local tw, th = self.tileW, self.tileH

  for _, s in ipairs(self.stars) do
    local ox = (-focusX * s.parallax) % tw
    local oy = (-focusY * s.parallax) % th
    local sx = (s.x + ox) % tw
    local sy = (s.y + oy) % th

    local twk = 0.92 + 0.08 * math.sin(self.time * s.twinkleSpeed + s.twinklePhase)
    local a = MathUtil.clamp(s.alpha * s.base * STAR_ALPHA_BOOST * twk, 0, 1)
    local size = (s.size <= 1.25) and 1 or 2

    love.graphics.setColor(s.cr or 1, s.cg or 1, s.cb or 1, a)

    for x = sx - tw, screenW + tw, tw do
      for y = sy - th, screenH + th, th do
        love.graphics.rectangle("fill", x, y, size, size)
      end
    end
  end
end

function SpaceBackground:draw(focusX, focusY)
  local screenW, screenH = love.graphics.getDimensions()

  local scale = self.renderScale or 1
  if scale <= 0 then
    scale = 1
  end

  local cw = math.max(1, math.floor(screenW * scale))
  local ch = math.max(1, math.floor(screenH * scale))

  if (not self.canvas) or self.canvasW ~= cw or self.canvasH ~= ch then
    self.canvasW = cw
    self.canvasH = ch
    self.canvas = love.graphics.newCanvas(cw, ch)
    self.canvas:setFilter("linear", "linear")
    self.redrawAcc = self.redrawInterval
  end

  local fx = focusX or 0
  local fy = focusY or 0

  if self.redrawInterval == 0 or self.redrawAcc >= self.redrawInterval or self.lastFocusX ~= fx or self.lastFocusY ~= fy then
    self.redrawAcc = 0
    self.lastFocusX = fx
    self.lastFocusY = fy

    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.01, 0.01, 0.03, 1)

    self:_drawNebula(cw, ch, fx, fy)

    love.graphics.setBlendMode("add")
    self:_drawStars(cw, ch, fx, fy)

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()
    love.graphics.pop()
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0, 0, 1 / scale, 1 / scale)
end

return SpaceBackground
