---@diagnostic disable: undefined-global
-- Component Definitions module
-- Defines all component types used in the ECS
-- Components are pure data structures with no logic

local Components = {}

-- Load component sub-modules
local physics = require('src.components.physics')
local rendering = require('src.components.rendering')
local control = require('src.components.control')
local ai = require('src.components.ai')
local ui = require('src.components.ui')
local combat = require('src.components.combat')
local equipment = require('src.components.equipment')
local cargo = require('src.components.cargo')
local entity = require('src.components.entity')
local warp_gate = require('src.components.warp_gate')

-- Merge all component definitions into the main Components table
for k, v in pairs(physics) do Components[k] = v end
for k, v in pairs(rendering) do Components[k] = v end
for k, v in pairs(control) do Components[k] = v end
for k, v in pairs(ai) do Components[k] = v end
for k, v in pairs(ui) do Components[k] = v end
for k, v in pairs(combat) do Components[k] = v end
for k, v in pairs(equipment) do Components[k] = v end
for k, v in pairs(cargo) do Components[k] = v end
for k, v in pairs(entity) do Components[k] = v end
for k, v in pairs(warp_gate) do Components[k] = v end

return Components
