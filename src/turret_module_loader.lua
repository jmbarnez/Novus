-- Utility to load turret module definitions by name
local M = {}

function M.getTurretModuleByName(name)
    local ok, mod = pcall(require, 'src.turret_modules.' .. name)
    if ok and type(mod) == 'table' then
        return mod
    end
    return nil
end

return M
