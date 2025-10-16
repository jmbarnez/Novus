-- Item loader: loads all items from src/items/
local itemDefs = {}
local lfs = love.filesystem
for _, file in ipairs(lfs.getDirectoryItems("src/items")) do
    if file:match("%.lua$") and file ~= "item_loader.lua" then
        local item = require("src.items." .. file:gsub("%.lua$", ""))
        itemDefs[item.id] = item
    end
end
return itemDefs
