---@diagnostic disable: undefined-global
-- Item loader: loads all items from src/items/
local itemDefs = {}
local lfs = love.filesystem
for _, file in ipairs(lfs.getDirectoryItems("src/items")) do
    if file:match("%.lua$") and file ~= "item_loader.lua" then
        local item = require("src.items." .. file:gsub("%.lua$", ""))
        itemDefs[item.id] = item
    end
end

-- Also load turret modules as items so modules are first-class inventory objects
if lfs.getDirectoryItems then
    for _, file in ipairs(lfs.getDirectoryItems("src/turret_modules")) do
        if file:match("%.lua$") then
            local ok, mod = pcall(require, "src.turret_modules." .. file:gsub("%.lua$", ""))
            if ok and type(mod) == "table" then
                -- Ensure module has a name token for item metadata
                mod.name = mod.name or mod.displayName or file:gsub("%.lua$", "")
                -- Build an item-like definition if not already present
                local id = (mod.id or mod.itemId or file:gsub("%.lua$", ""))
                if not itemDefs[id] then
                    local itemDef = {
                        id = id,
                        name = mod.name,
                        description = mod.description or "",
                        type = "turret",
                        stackable = false,
                        volume = mod.volume or 0.5,
                        value = mod.value or 150,
                        module = mod, -- attach module behavior table
                    }
                    itemDefs[id] = itemDef
                end
            end
        end
    end
end
return itemDefs
