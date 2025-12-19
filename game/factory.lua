local factory = {}

local Walls = require("game.factory.walls")
local Ship = require("game.factory.ship")
local Player = require("game.factory.player")
local Asteroids = require("game.factory.asteroids")

factory.createWalls = Walls.createWalls
factory.createShip = Ship.createShip
factory.createPlayer = Player.createPlayer
factory.createAsteroid = Asteroids.createAsteroid
factory.spawnAsteroids = Asteroids.spawnAsteroids

return factory
