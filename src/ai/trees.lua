-- Expose all AI behavior trees for easy assignment
local miningTree = require('src.ai.mining_bt')
local combatTree = require('src.ai.combat_bt')

return {
    mining = miningTree,
    combat = combatTree
}
