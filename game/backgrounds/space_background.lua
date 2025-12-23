local SpaceBackground = {}
SpaceBackground.__index = SpaceBackground

local MathUtil = require("util.math")

-- Configuration constants
local CONFIG = {
  STAR_ALPHA_BOOST = 1.8,
  NEBULA_PARALLAX = 0.00015,
  NEBULA_TIME_SCALE = 0.1,
  NEBULA_SHADER_PATH = "game/shaders/nebula.glsl",

  -- Default starfield parameters
  DEFAULT_TILE_SIZE = 1024,
  DEFAULT_DENSITY = 0.0007,
  DEFAULT_PARALLAX_MIN = 0.00002,
  DEFAULT_PARALLAX_MAX = 0.0010,
  DEFAULT_DEPTH_POWER = 3,

  -- Star color thresholds
  PARALLAX_NEAR = 0.00025,
  PARALLAX_MID = 0.0009,
}

-- Star color palettes by depth layer
local STAR_COLORS = {
  near = {
    { prob = 0.85, color = { 0.92, 0.95, 1.00 } },
    { prob = 1.00, color = { 0.70, 0.82, 1.00 } },
  },
  mid = {
    { prob = 0.70, color = { 0.95, 0.97, 1.00 } },
    { prob = 0.90, color = { 0.72, 0.85, 1.00 } },
    { prob = 1.00, color = { 1.00, 0.92, 0.75 } },
  },
  far = {
    { prob = 0.55, color = { 0.98, 0.99, 1.00 } },
    { prob = 0.75, color = { 0.75, 0.88, 1.00 } },
    { prob = 1.00, color = { 1.00, 0.88, 0.65 } },
  },
}

local function selectFromPalette(rng, palette)
  local t = rng:random()
  for _, entry in ipairs(palette) do
    if t < entry.prob then
      return entry.color[1], entry.color[2], entry.color[3]
    end
  end
  local last = palette[#palette].color
  return last[1], last[2], last[3]
end

local function pickStarColor(rng, parallax)
  local palette
  if parallax <= CONFIG.PARALLAX_NEAR then
    palette = STAR_COLORS.near
  elseif parallax <= CONFIG.PARALLAX_MID then
    palette = STAR_COLORS.mid
  else
    palette = STAR_COLORS.far
  end

  local r, g, b = selectFromPalette(rng, palette)
  local brightness = 0.90 + 0.10 * rng:random()
  return r * brightness, g * brightness, b * brightness
end

local function createStar(rng, tileW, tileH, parallax)
  local cr, cg, cb = pickStarColor(rng, parallax)
  local t = (parallax - CONFIG.DEFAULT_PARALLAX_MIN) / (CONFIG.DEFAULT_PARALLAX_MAX - CONFIG.DEFAULT_PARALLAX_MIN)

  return {
    x = math.floor(rng:random() * tileW),
    y = math.floor(rng:random() * tileH),
    size = 1 + 1.6 * (t * t),
    base = 0.65 + 0.35 * rng:random(),
    cr = cr,
    cg = cg,
    cb = cb,
    alpha = 0.22 + 0.26 * t,
    parallax = parallax,
    twinklePhase = rng:random() * math.pi * 2,
    twinkleSpeed = 0.4 + 1.2 * rng:random(),
  }
end

local function buildStarfield(rng, tileW, tileH, density, parallaxMin, parallaxMax, depthPower)
  local stars = {}
  local count = math.floor(tileW * tileH * density)

  for i = 1, count do
    local t = rng:random() ^ depthPower
    local parallax = parallaxMin + (parallaxMax - parallaxMin) * t
    stars[i] = createStar(rng, tileW, tileH, parallax)
  end

  return stars
end

local function loadNebulaShader()
  local ok, sourceOrErr = pcall(love.filesystem.read, CONFIG.NEBULA_SHADER_PATH)
  if not ok or not sourceOrErr then
    print("Failed to read nebula shader file: " .. tostring(sourceOrErr))
    return nil
  end

  local okShader, shaderOrErr = pcall(love.graphics.newShader, sourceOrErr)
  if not okShader then
    print("Failed to compile nebula shader: " .. tostring(shaderOrErr))
    return nil
  end

  return shaderOrErr
end

local function normalizeNebulaSeed(rng, nebulaSeed)
  if nebulaSeed == nil then
    return rng:random() * 1000
  end

  if type(nebulaSeed) == "number" and math.abs(nebulaSeed) > 10000 then
    local m = 1000000
    return (nebulaSeed % m) / m * 1000
  end

  return nebulaSeed
end

function SpaceBackground.new(opts)
  opts = opts or {}

  local self = setmetatable({}, SpaceBackground)

  local seed = opts.seed or love.math.random(1, 1000000000)
  self.rng = love.math.newRandomGenerator(seed)

  -- Timing state
  self.time = 0
  local updateHz = opts.updateHz or 0
  self.redrawInterval = (updateHz > 0) and (1 / updateHz) or 0
  self.redrawAcc = 0

  -- Rendering state
  self.renderScale = opts.renderScale or 1
  self.canvas = nil
  self.canvasW = 0
  self.canvasH = 0
  self.lastFocusX = nil
  self.lastFocusY = nil

  -- Shader resources
  self.nebulaSeed = normalizeNebulaSeed(self.rng, opts.nebulaSeed)
  self.nebulaShader = loadNebulaShader()
  self._shaderResolution = { 0, 0 }
  self._shaderOffset = { 0, 0 }

  -- Starfield configuration
  self.tileW = opts.tileW or CONFIG.DEFAULT_TILE_SIZE
  self.tileH = opts.tileH or CONFIG.DEFAULT_TILE_SIZE

  self.stars = buildStarfield(
    self.rng,
    self.tileW,
    self.tileH,
    opts.density or CONFIG.DEFAULT_DENSITY,
    opts.parallaxMin or CONFIG.DEFAULT_PARALLAX_MIN,
    opts.parallaxMax or CONFIG.DEFAULT_PARALLAX_MAX,
    opts.depthPower or CONFIG.DEFAULT_DEPTH_POWER
  )

  self.enableNebula = true

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

  self.nebulaShader:send("time", self.time * CONFIG.NEBULA_TIME_SCALE)

  self._shaderResolution[1] = screenW
  self._shaderResolution[2] = screenH
  self.nebulaShader:send("resolution", self._shaderResolution)

  self._shaderOffset[1] = -focusX * CONFIG.NEBULA_PARALLAX
  self._shaderOffset[2] = -focusY * CONFIG.NEBULA_PARALLAX
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

  for _, star in ipairs(self.stars) do
    local ox = (-focusX * star.parallax) % tw
    local oy = (-focusY * star.parallax) % th
    local sx = (star.x + ox) % tw
    local sy = (star.y + oy) % th

    local twinkle = 0.92 + 0.08 * math.sin(self.time * star.twinkleSpeed + star.twinklePhase)
    local alpha = MathUtil.clamp(star.alpha * star.base * CONFIG.STAR_ALPHA_BOOST * twinkle, 0, 1)
    local size = (star.size <= 1.25) and 1 or 2

    love.graphics.setColor(star.cr, star.cg, star.cb, alpha)

    for x = sx - tw, screenW + tw, tw do
      for y = sy - th, screenH + th, th do
        love.graphics.rectangle("fill", x, y, size, size)
      end
    end
  end
end

function SpaceBackground:_ensureCanvas(screenW, screenH)
  local scale = math.max(self.renderScale or 1, 0.001)
  local cw = math.max(1, math.floor(screenW * scale))
  local ch = math.max(1, math.floor(screenH * scale))

  if self.canvas and self.canvasW == cw and self.canvasH == ch then
    return cw, ch, scale
  end

  self.canvasW = cw
  self.canvasH = ch
  self.canvas = love.graphics.newCanvas(cw, ch)
  self.canvas:setFilter("linear", "linear")
  self.redrawAcc = self.redrawInterval

  return cw, ch, scale
end

function SpaceBackground:_needsRedraw(focusX, focusY)
  if self.redrawInterval == 0 then
    return true
  end
  if self.redrawAcc >= self.redrawInterval then
    return true
  end
  if self.lastFocusX ~= focusX or self.lastFocusY ~= focusY then
    return true
  end
  return false
end

function SpaceBackground:draw(focusX, focusY)
  local screenW, screenH = love.graphics.getDimensions()
  local cw, ch, scale = self:_ensureCanvas(screenW, screenH)

  local fx = focusX or 0
  local fy = focusY or 0

  if self:_needsRedraw(fx, fy) then
    self.redrawAcc = 0
    self.lastFocusX = fx
    self.lastFocusY = fy

    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0.01, 0.01, 0.03, 1)

    if self.enableNebula then
      self:_drawNebula(cw, ch, fx, fy)
    end

    love.graphics.setBlendMode("add")
    self:_drawStars(cw, ch, fx, fy)

    love.graphics.setCanvas()
    love.graphics.pop()
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0, 0, 1 / scale, 1 / scale)
end

return SpaceBackground
