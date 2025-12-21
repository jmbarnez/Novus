local factory = {}

local Walls = require("game.factory.walls")
local Ship = require("game.factory.ship")
local Player = require("game.factory.player")
local Asteroids = require("game.factory.asteroids")
local SpaceStation = require("game.factory.space_station")
local Rng = require("util.rng")

factory.createWalls = Walls.createWalls
factory.createShip = Ship.createShip
factory.createPlayer = Player.createPlayer
factory.createSpaceStation = SpaceStation.createSpaceStation
factory.createAsteroid = function(ecsWorld, physicsWorld, x, y, radius, rng, oreId)
  return Asteroids.createAsteroid(ecsWorld, physicsWorld, x, y, radius, Rng.ensure(rng), oreId)
end
factory.spawnAsteroids = function(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius, rng)
  return Asteroids.spawnAsteroids(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius, Rng.ensure(rng))
end

return factory
