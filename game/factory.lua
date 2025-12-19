local factory = {}

local Walls = require("game.factory.walls")
local Ship = require("game.factory.ship")
local Player = require("game.factory.player")
local Asteroids = require("game.factory.asteroids")

local function ensureRng(rng)
  if rng then
    return rng
  end

  return love.math.newRandomGenerator(love.math.random(1, 2147483646))
end

factory.createWalls = Walls.createWalls
factory.createShip = Ship.createShip
factory.createPlayer = Player.createPlayer
factory.createAsteroid = function(ecsWorld, physicsWorld, x, y, radius, rng)
  return Asteroids.createAsteroid(ecsWorld, physicsWorld, x, y, radius, ensureRng(rng))
end
factory.spawnAsteroids = function(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius, rng)
  return Asteroids.spawnAsteroids(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius, ensureRng(rng))
end

return factory
