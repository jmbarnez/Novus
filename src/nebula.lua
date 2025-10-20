-- src/nebula.lua
-- DEPRECATED: Nebula system has been removed

local Nebula = {}

-- Empty stub functions for backwards compatibility
function Nebula.spawnCloud() end
function Nebula.createCloud() end
function Nebula.removeCloud() end
function Nebula.clearClouds() end
function Nebula.getCloud() end
function Nebula.generateRandomClouds() end
function Nebula.initialize() end
function Nebula.drawInWorldSpace() end
function Nebula.draw() end
function Nebula.getClouds() return {} end
function Nebula.getCloudCount() return 0 end

return Nebula
