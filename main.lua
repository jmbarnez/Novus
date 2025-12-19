local Gamestate = require("lib.hump.gamestate")
local Space = require("states.space")

function love.load()
  love.physics.setMeter(64)
  love.math.setRandomSeed(love.timer.getTime())

  love.graphics.setDefaultFilter("nearest", "nearest")

  Gamestate.registerEvents()
  Gamestate.switch(Space)
end
