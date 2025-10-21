-- Systems module
-- Aggregates all ECS systems from individual system files
-- Provides centralized access to all game systems

local Systems = {}

-- Load individual system modules
Systems.PhysicsSystem = require('src.systems.physics')
Systems.PhysicsCollisionSystem = require('src.systems.physics_collision')
Systems.BoundarySystem = require('src.systems.boundary')
Systems.InputSystem = require('src.systems.input')
Systems.RenderSystem = require('src.systems.render')
Systems.CameraSystem = require('src.systems.camera')
Systems.UISystem = require('src.systems.ui')
Systems.HUDSystem = require('src.systems.hud')
Systems.TrailSystem = require('src.systems.trail')
Systems.AISystem = require('src.systems.ai')
Systems.CollisionSystem = require('src.systems.collision').CollisionSystem
Systems.MagnetSystem = require('src.systems.magnet')
Systems.DestructionSystem = require('src.systems.destruction')
Systems.DebrisSystem = require('src.systems.debris')
Systems.TurretSystem = require('src.systems.turret')
Systems.TurretEffectsSystem = require('src.systems.turret_effects')
Systems.MissileSystem = require('src.systems.homing_missile')
Systems.ProjectileSystem = require('src.systems.projectile')
Systems.SoundSystem = require('src.systems.sound')
Systems.WrackageSystem = require('src.systems.wreckage')
Systems.AIArbiterSystem = require('src.systems.ai_arbiter')
Systems.ShieldImpactSystem = require('src.systems.shield_impact')

return Systems
