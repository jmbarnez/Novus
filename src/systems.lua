-- Systems module
-- Aggregates all ECS systems from individual system files
-- Provides centralized access to all game systems

local Systems = {}

-- Load individual system modules
Systems.PhysicsSystem = require('src.systems.physics')
Systems.BoundarySystem = require('src.systems.boundary')
Systems.InputSystem = require('src.systems.input')
Systems.RenderSystem = require('src.systems.render')
Systems.CameraSystem = require('src.systems.camera')
Systems.UISystem = require('src.systems.ui')
Systems.TrailSystem = require('src.systems.trail')
Systems.CollisionSystem = require('src.systems.collision').CollisionSystem
Systems.MiningSystem = require('src.systems.mining')
Systems.DestructionSystem = require('src.systems.destruction')
Systems.DebrisSystem = require('src.systems.debris')

return Systems
