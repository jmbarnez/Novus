---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local Items = require('src.items.item_loader')
local UIUtils = require('src.ui.ui_utils')
local ECS = require('src.ecs')
local Notifications = require('src.ui.notifications')
local ContextMenu = require('src.ui.context_menu')

local ShopWindow = WindowBase:new{
    width = 900,
    height = 650,
    isOpen = false
}

-- State
ShopWindow.currentStationId = nil
ShopWindow.items = nil -- cached shop item defs
ShopWindow.shopSearchQuery = ""
ShopWindow.searchFocused = false
ShopWindow.selectedIndex = nil

function ShopWindow:ensureItems()
    if not self.items then
        self.items = {}
        for id, def in pairs(Items) do
            table.insert(self.items, { id = id, def = def })
        end
        table.sort(self.items, function(a,b) return (a.def.name or a.id) < (b.def.name or b.id) end)
    end
end

-- Build unified item list with both shop and player quantities
local function buildUnifiedItemList(shopItems, cargo)
    local ItemDefs = require('src.items.item_loader')
    local unified = {}
    local seenIds = {}
    
    -- Add shop items
    for _, shopItem in ipairs(shopItems) do
        local id = shopItem.id
        if not seenIds[id] then
            seenIds[id] = true
            local playerCount = cargo and (cargo.items[id] or 0) or 0
            unified[id] = {
                id = id,
                def = shopItem.def,
                shopCount = -1, -- -1 means unlimited/available
                playerCount = playerCount
            }
        end
    end
    
    -- Add player items that aren't in shop
    if cargo then
        for id, count in pairs(cargo.items or {}) do
            if not seenIds[id] then
                local def = ItemDefs[id]
                if def then
                    unified[id] = {
                        id = id,
                        def = def,
                        shopCount = 0, -- Not available in shop
                        playerCount = count
                    }
                end
            else
                -- Update player count for existing items
                unified[id].playerCount = count
            end
        end
    end
    
    -- Convert to sorted array
    local list = {}
    for _, item in pairs(unified) do
        table.insert(list, item)
    end
    table.sort(list, function(a,b) return (a.def.name or a.id) < (b.def.name or b.id) end)
    return list
end

function ShopWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    if not self:getOpen() and (not self.animAlphaActive) then return end
    self:ensureItems()
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end

    local alpha = self.animAlpha or 1
    love.graphics.push('all')
    local x, y = self.position.x, self.position.y
    local w, h = self.width, self.height
    local padding = 12

    -- Header
    local titleFont = Theme.getFont(Theme.fonts.title)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.print("Station Shop", x + padding, y + padding)
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    -- Top controls (Back button only)
    local controlsY = y + Theme.window.topBarHeight + 8
    local controlsH = 34
    self.shopControlButtons = {}
    local btnW = 100
    local bx = x + padding

    -- Back button
    local font = Theme.getFont(Theme.fonts.small)
    love.graphics.setFont(font)
    local bg = Theme.colors.surface
    local border = Theme.colors.border
    local corner = Theme.window.cornerRadius or 0
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.95 * alpha)
    love.graphics.rectangle("fill", bx, controlsY, btnW, controlsH, corner, corner)
    love.graphics.setColor(border[1], border[2], border[3], 0.6 * alpha)
    love.graphics.rectangle("line", bx, controlsY, btnW, controlsH, corner, corner)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("Back", bx, controlsY + 8, btnW, "center")
    self.shopControlButtons["back"] = { x = bx, y = controlsY, w = btnW, h = controlsH }

    -- Content area
    local contentX = x + 10
    local contentY = controlsY + controlsH + 8
    local contentW = w - 20
    local contentH = h - Theme.window.topBarHeight - Theme.window.bottomBarHeight - controlsH - 40

    -- Get player cargo for unified list
    local EntityHelpers = require('src.entity_helpers')
    local droneId = EntityHelpers.getPlayerShip()
    local cargo = droneId and ECS.getComponent(droneId, "Cargo")
    
    -- Build unified item list
    local unifiedList = buildUnifiedItemList(self.items, cargo)
    
    -- Filter by search query
    local itemsList = {}
    local q = (self.shopSearchQuery or ""):lower()
    for _, item in ipairs(unifiedList) do
        local name = (item.def.name or item.id):lower()
        if q == "" or name:find(q, 1, true) then
            table.insert(itemsList, item)
        end
    end

    -- Draw grid of items (icons)
    local slotSize = 72
    local slotPadding = 10
    local slotsPerRow = math.floor(contentW / (slotSize + slotPadding))
    if slotsPerRow < 1 then slotsPerRow = 1 end
    local mx, my = UIUtils.getMousePosition()
    self.hoveredItemSlot = nil
    
    -- Calculate total slot height including text
    local slotTotalHeight = slotSize + 50 -- space for name + quantities + price
    
    for i, item in ipairs(itemsList) do
        local row = math.floor((i - 1) / slotsPerRow)
        local col = (i - 1) % slotsPerRow
        local slotX = contentX + col * (slotSize + slotPadding)
        local slotY = contentY + row * (slotTotalHeight + slotPadding)
        local isHovered = UIUtils.pointInRect(mx, my, slotX, slotY, slotSize, slotTotalHeight)
        if isHovered then
            self.hoveredItemSlot = { index = i, item = item }
        end

        local bg = Theme.colors.surface
        local border = isHovered and Theme.colors.hover or Theme.colors.border
        local corner = Theme.window.cornerRadius or 0
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.9 * alpha)
        love.graphics.rectangle('fill', slotX, slotY, slotSize, slotSize, corner, corner)
        love.graphics.setColor(border[1], border[2], border[3], 0.6 * alpha)
        love.graphics.rectangle('line', slotX, slotY, slotSize, slotSize, corner, corner)

        -- Draw icon
        local def = item.def
        if def then
            local cx = slotX + slotSize / 2
            local cy = slotY + slotSize / 2
            UIUtils.drawItemIcon(def, cx, cy, alpha, 1.0)
        end

        -- Draw name, quantities, and price
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        local labelY = slotY + slotSize + 4
        local label = (def and def.name) or item.id or ""
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(label, slotX, labelY, slotSize, "center")
        
        -- Shop count and player count
        local infoY = labelY + 12
        local shopCount = item.shopCount or 0
        local playerCount = item.playerCount or 0
        local shopText = shopCount == -1 and "Shop: ∞" or (shopCount > 0 and ("Shop: " .. shopCount) or "Shop: -")
        local playerText = "You: " .. playerCount
        
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        -- Shop count (green if available)
        if shopCount == -1 or shopCount > 0 then
            local shopColor = Theme.colors.success or {0.1, 0.8, 0.5, 1}
            love.graphics.setColor(shopColor[1], shopColor[2], shopColor[3], alpha)
        else
            local mutedColor = Theme.colors.textSecondary or {0.5, 0.5, 0.5, 1}
            love.graphics.setColor(mutedColor[1], mutedColor[2], mutedColor[3], alpha)
        end
        love.graphics.printf(shopText, slotX, infoY, slotSize, "center")
        
        -- Player count
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(playerText, slotX, infoY + 12, slotSize, "center")
        
        -- Price
        local priceY = infoY + 24
        local price = (def and def.value) or 0
        love.graphics.setColor(Theme.colors.textAccent[1] or 1, Theme.colors.textAccent[2] or 0.8, Theme.colors.textAccent[3] or 0.6, alpha)
        love.graphics.printf(string.format("%d c", price), slotX, priceY, slotSize, "center")
    end

    -- Draw bottom bar with credits and search box
    local bottomBarH = Theme.window.bottomBarHeight or 36
    local bx = x
    local by = y + h - bottomBarH
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local fontH = love.graphics.getFont():getHeight()

    -- Credits
    local pilotId = (require('src.entity_helpers').getPlayerPilot())
    local wallet = pilotId and ECS.getComponent(pilotId, "Wallet")
    local credits = wallet and wallet.credits or 0
    local coinSize = fontH + 6
    local coinX = bx + padding + coinSize / 2
    local coinY = by + bottomBarH / 2
    local coinColor = Theme.colors.textAccent or Theme.palette.accent
    love.graphics.setColor(coinColor[1], coinColor[2], coinColor[3], alpha)
    love.graphics.circle('fill', coinX, coinY, coinSize / 2)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.print(string.format('%d', credits), bx + padding + coinSize + 8, by + (bottomBarH - fontH) / 2)

    -- Search box on right
    local searchW = 260
    local searchH = 28
    local searchX = x + w - searchW - padding
    local searchY = by + (bottomBarH - searchH) / 2
    self.shopSearchRect = { x = searchX, y = searchY, w = searchW, h = searchH }
    local bg = Theme.colors.surface
    local border = Theme.colors.border
    local corner = Theme.window.cornerRadius or 0
    if self.searchFocused then
        local focusBg = Theme.colors.surfaceAlt or Theme.colors.surface
        love.graphics.setColor(focusBg[1], focusBg[2], focusBg[3], 0.95 * alpha)
        love.graphics.rectangle('fill', searchX - 1, searchY - 1, searchW + 2, searchH + 2, corner, corner)
    end
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.95 * alpha)
    love.graphics.rectangle('fill', searchX, searchY, searchW, searchH, corner, corner)
    love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
    love.graphics.rectangle('line', searchX, searchY, searchW, searchH, corner, corner)
    local placeholder = "Search..."
    local query = self.shopSearchQuery or ""
    local showPlaceholder = query == "" and not self.searchFocused
    love.graphics.setScissor(searchX + 8, searchY, searchW - 16, searchH)
    if showPlaceholder then
        local tc = Theme.colors.textSecondary
        love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * alpha)
        love.graphics.printf(placeholder, searchX + 8, searchY + 6, searchW - 16, "left")
    else
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(query, searchX + 8, searchY + 6, searchW - 16, "left")
        if self.searchFocused then
            local caretX = searchX + 8 + love.graphics.getFont():getWidth(query)
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.6 * alpha)
            love.graphics.line(caretX, searchY + 8, caretX, searchY + searchH - 8)
        end
    end
    love.graphics.setScissor()

    love.graphics.pop()
end

function ShopWindow:mousepressed(x, y, button)
    if ContextMenu and ContextMenu.isOpen and ContextMenu.isOpen() then
        -- let cargo/other handle
    end
    WindowBase.mousepressed(self, x, y, button)
    if not self:getOpen() then return true end
    if self.isDragging then return true end

    -- Top buttons
    if self.shopControlButtons then
        for id, rect in pairs(self.shopControlButtons) do
            if UIUtils.pointInRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if id == "back" then
                    self:setOpen(false)
                    return true
                end
            end
        end
    end

    -- Search box
    if self.shopSearchRect and UIUtils.pointInRect(x, y, self.shopSearchRect.x, self.shopSearchRect.y, self.shopSearchRect.w, self.shopSearchRect.h) then
        self.searchFocused = true
        return true
    else
        self.searchFocused = false
    end

    -- Click on items: left-click = buy, right-click = sell
    if self.hoveredItemSlot then
        local selected = self.hoveredItemSlot.item
        if not selected then return false end
        
        local EntityHelpers = require('src.entity_helpers')
        local pilotId = EntityHelpers.getPlayerPilot()
        local droneId = EntityHelpers.getPlayerShip()
        local wallet = pilotId and ECS.getComponent(pilotId, "Wallet")
        local cargo = droneId and ECS.getComponent(droneId, "Cargo")
        
        if button == 1 then
            -- Left-click: Buy
            local shopCount = selected.shopCount or 0
            if shopCount == -1 or shopCount > 0 then
                local price = (selected.def and selected.def.value) or 0
                if wallet and wallet.credits and wallet.credits >= price then
                    if cargo and cargo.addItem and cargo:canAddItem(selected.id, 1) then
                        wallet.credits = wallet.credits - price
                        cargo:addItem(selected.id, 1)
                        Notifications.addItemNotification(selected.id, 1)
                    else
                        if Notifications and Notifications.addNotification then
                            Notifications.addNotification{ type = 'item', text = 'Not enough cargo space', timer = 2 }
                        end
                    end
                else
                    if Notifications and Notifications.addNotification then
                        Notifications.addNotification{ type = 'item', text = 'Not enough credits', timer = 2 }
                    end
                end
            else
                if Notifications and Notifications.addNotification then
                    Notifications.addNotification{ type = 'item', text = 'Item not available in shop', timer = 2 }
                end
            end
            return true
        elseif button == 2 then
            -- Right-click: Sell
            local playerCount = selected.playerCount or 0
            if playerCount > 0 and cargo and cargo.removeItem then
                local sellPrice = math.floor((selected.def and selected.def.value or 0) * 0.5)
                local removed = cargo:removeItem(selected.id, 1)
                if removed then
                    if wallet then wallet.credits = (wallet.credits or 0) + sellPrice end
                    if Notifications and Notifications.addNotification then
                        local itemName = (selected.def and selected.def.name) or selected.id
                        Notifications.addNotification{ type = 'item', text = string.format('Sold: %s (+%d c)', itemName, sellPrice), timer = 2 }
                    end
                else
                    if Notifications and Notifications.addNotification then
                        Notifications.addNotification{ type = 'item', text = 'Nothing to sell', timer = 2 }
                    end
                end
            else
                if Notifications and Notifications.addNotification then
                    Notifications.addNotification{ type = 'item', text = 'You don\'t have this item', timer = 2 }
                end
            end
            return true
        end
    end

    return false
end

function ShopWindow:keypressed(key)
    if not self.searchFocused then return false end
    if key == 'backspace' then
        local q = self.shopSearchQuery or ''
        self.shopSearchQuery = q:sub(1, math.max(0, #q - 1))
        return true
    elseif key == 'escape' then
        self.searchFocused = false
        return true
    elseif key == 'return' or key == 'kpenter' then
        self.searchFocused = false
        return true
    end
    return false
end

function ShopWindow:textinput(t)
    if not self.searchFocused then return false end
    t = t or ''
    self.shopSearchQuery = (self.shopSearchQuery or '') .. t
    if #self.shopSearchQuery > 64 then
        self.shopSearchQuery = self.shopSearchQuery:sub(1,64)
    end
    return true
end

return ShopWindow


