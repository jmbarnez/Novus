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
    local function humanizeId(id)
        if not id or type(id) ~= "string" then return id end
        local s = id:gsub("_", " ")
        s = s:gsub("%f[%a].", function(c) return string.upper(c) end)
        return s
    end
    for _, file in ipairs(lfs.getDirectoryItems("src/turret_modules")) do
        if file:match("%.lua$") then
            local ok, mod = pcall(require, "src.turret_modules." .. file:gsub("%.lua$", ""))
            if ok and type(mod) == "table" then
                -- Ensure module has a name token for item metadata
                mod.name = mod.name or file:gsub("%.lua$", "")
                -- Build an item-like definition if not already present
                local id = (mod.id or mod.itemId or file:gsub("%.lua$", ""))
                if not itemDefs[id] then
                    local itemDef = {
                        id = id,
                        name = mod.displayName or humanizeId(id),
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

-- Load sub-modules (generic attachments) as items
if lfs.getDirectoryItems then
    local function humanizeId2(id)
        if not id or type(id) ~= "string" then return id end
        local s = id:gsub("_", " ")
        s = s:gsub("%f[%a].", function(c) return string.upper(c) end)
        return s
    end
    if lfs.getInfo("src/sub_modules") then
        for _, file in ipairs(lfs.getDirectoryItems("src/sub_modules")) do
            if file:match("%.lua$") then
                local ok, mod = pcall(require, "src.sub_modules." .. file:gsub("%.lua$", ""))
                if ok and type(mod) == "table" then
                    local id = (mod.id or mod.itemId or file:gsub("%.lua$", ""))
                    if not itemDefs[id] then
                        itemDefs[id] = {
                            id = id,
                            name = mod.displayName or humanizeId2(id),
                            description = mod.description or "",
                            type = "submodule",
                            stackable = false,
                            volume = mod.volume or 0.1,
                            value = mod.value or 75,
                            submodule = mod
                        }
                    end
                end
            end
        end
    end
end
return itemDefs
