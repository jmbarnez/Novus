local Gamestate = require("lib.hump.gamestate")
local Space = require("states.space")

function love.load()
  love.physics.setMeter(64)
  local seed1 = os.time()
  local seed2 = math.floor(love.timer.getTime() * 1000000)
  love.math.setRandomSeed(seed1, seed2)
  love.math.random()
  love.math.random()
  love.math.random()

  love.graphics.setDefaultFilter("nearest", "nearest")

  Gamestate.registerEvents()
  Gamestate.switch(Space)
end
