--[[
  Sound System

  ECS system that listens for game events and triggers appropriate sound effects.
  Works with the Sound manager module for actual audio playback.
]]

local Concord = require("lib.concord")
local Sound = require("game.sound")

local SoundSystem = Concord.system()

function SoundSystem:init(world)
    self.world = world
end

--------------------------------------------------------------------------------
-- Weapon Events
--------------------------------------------------------------------------------

function SoundSystem:onWeaponFired(ship, weapon)
    Sound.play("laser_fire", {
        pitchVariation = 0.1,
        volumeVariation = 0.05,
    })
end

--------------------------------------------------------------------------------
-- Combat Events
--------------------------------------------------------------------------------

function SoundSystem:onProjectileImpact(x, y)
    Sound.play("impact", {
        pitchVariation = 0.15,
        volumeVariation = 0.1,
    })
end

function SoundSystem:onAsteroidDestroyed(entity, x, y, radius)
    Sound.play("explosion_small", {
        pitchVariation = 0.2,
        volumeVariation = 0.1,
    })
end

--------------------------------------------------------------------------------
-- Collection Events
--------------------------------------------------------------------------------

function SoundSystem:onItemCollected(ship, itemId, amount)
    -- Only play for player ship
    local player = self.world:getResource("player")
    if not player or not player.pilot or player.pilot.ship ~= ship then
        return
    end

    Sound.play("pickup", {
        pitchVariation = 0.1,
    })
end

--------------------------------------------------------------------------------
-- Quest Events
--------------------------------------------------------------------------------

function SoundSystem:onQuestCompleted(quest)
    Sound.play("quest_complete")
end

--------------------------------------------------------------------------------
-- UI Events
--------------------------------------------------------------------------------

function SoundSystem:onStationDocked(station)
    Sound.play("dock")
end

function SoundSystem:onUIClick()
    Sound.play("ui_click", {
        pitchVariation = 0.05,
    })
end

return SoundSystem
