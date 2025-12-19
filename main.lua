local Gamestate = require("lib.hump.gamestate")
local Space = require("states.space")
local Seed = require("util.seed")

function love.load()
  love.physics.setMeter(64)
  local seed1 = os.time()
  local seed2 = math.floor(love.timer.getTime() * 1000000)
  local worldSeed = Seed.normalize(seed1 * 1000000 + seed2)
  love.math.setRandomSeed(worldSeed, Seed.derive(worldSeed, "global"))
  love.math.random()
  love.math.random()
  love.math.random()

  love.graphics.setDefaultFilter("nearest", "nearest")

  Gamestate.registerEvents()
  Gamestate.switch(Space, worldSeed)
end
