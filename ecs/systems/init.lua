local Systems = {}

Systems.InputSystem = require("ecs.systems.input_system")
Systems.ShipControlSystem = require("ecs.systems.ship_control_system")
Systems.ContactFlashSystem = require("ecs.systems.contact_flash_system")
Systems.ProjectileHitSystem = require("ecs.systems.projectile_hit_system")
Systems.HitFlashSystem = require("ecs.systems.hit_flash_system")
Systems.HealthSystem = require("ecs.systems.health_system")
Systems.ProjectileSystem = require("ecs.systems.projectile_system")
Systems.ShatterSystem = require("ecs.systems.shatter_system")
Systems.EngineTrailSystem = require("ecs.systems.engine_trail_system")
Systems.LaserBeamSystem = require("ecs.systems.laser_beam_system")
Systems.WeaponSystem = require("ecs.systems.weapon_system")
Systems.PickupSystem = require("ecs.systems.pickup_system")
Systems.MagnetSystem = require("ecs.systems.magnet_system")
Systems.PhysicsSnapshotSystem = require("ecs.systems.physics_snapshot_system")
Systems.TargetingSystem = require("ecs.systems.targeting_system")
Systems.RenderSystem = require("ecs.systems.render_system")
Systems.HudSystem = require("ecs.systems.hud_system")

return Systems
