---@diagnostic disable: undefined-global
-- Station Window - Unified window with tabs for Quest and Shop
-- Opens when docking at a station

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local QuestWindow = require('src.ui.quest_window')
local ShopWindow = require('src.ui.shop_window')
local UIUtils = require('src.ui.ui_utils')

local StationWindow = WindowBase:new{
    width = 900,
    height = 650,
    isOpen = false
}

-- Tab management
StationWindow.activeTab = "quest" -- "quest" or "shop"
StationWindow.tabs = {"quest", "shop"}
StationWindow.tabNames = {
    quest = "Quest Board",
    shop = "Shop"
}
StationWindow.tabButtons = {}

-- Store current station ID
StationWindow.currentStationId = nil

-- Helper to build unified item list (moved from ShopWindow)
local function buildUnifiedItemList(shopItems, cargo)
    local ItemDefs = require('src.items.item_loader')
    local unified = {}
    local seenIds = {}
    
    for _, shopItem in ipairs(shopItems) do
        local id = shopItem.id
        if not seenIds[id] then
            seenIds[id] = true
            local playerCount = cargo and (cargo.items[id] or 0) or 0
            unified[id] = {
                id = id,
                def = shopItem.def,
                shopCount = -1,
                playerCount = playerCount
            }
        end
    end
    
    if cargo then
        for id, count in pairs(cargo.items or {}) do
            if not seenIds[id] then
                local def = ItemDefs[id]
                if def then
                    unified[id] = {
                        id = id,
                        def = def,
                        shopCount = 0,
                        playerCount = count
                    }
                end
            else
                unified[id].playerCount = count
            end
        end
    end
    
    local list = {}
    for _, item in pairs(unified) do
        table.insert(list, item)
    end
    table.sort(list, function(a,b) return (a.def.name or a.id) < (b.def.name or b.id) end)
    return list
end

function StationWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if not state then
        self.currentStationId = nil
        -- Also close individual windows if they were open
        QuestWindow:setOpen(false)
        ShopWindow:setOpen(false)
    else
        -- Set station ID on child windows
        if self.currentStationId then
            QuestWindow.currentStationId = self.currentStationId
            ShopWindow.currentStationId = self.currentStationId
        end
    end
end

function StationWindow:getOpen()
    return self.isOpen
end

function StationWindow:toggle()
    self:setOpen(not self.isOpen)
end

-- Keep tabs compact
local NAV_BUTTON_HEIGHT = math.min(Theme.window.tabHeight or 60, 42)

function StationWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    if not self:getOpen() and (not self.animAlphaActive) then return end
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end

    local alpha = self.animAlpha or 1
    if alpha <= 0 then return end

    -- Get mouse position if not provided
    if not uiMx or not uiMy then
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiMx, uiMy = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiMx, uiMy = Scaling.toUI(love.mouse.getPosition())
        end
    end

    local x, y = self.position.x, self.position.y
    local w, h = self.width, self.height
    local topBarH = Theme.window.topBarHeight or 0

    -- Draw close button
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    -- Draw tab headers
    self:drawSectionButtons(x, y, alpha, uiMx, uiMy)

    -- Draw content based on active tab
    local contentY = y + topBarH + NAV_BUTTON_HEIGHT
    local contentH = h - topBarH - NAV_BUTTON_HEIGHT - (Theme.window.bottomBarHeight or 0)

    if self.activeTab == "quest" then
        self:drawQuestContent(x, contentY, w, contentH, alpha)
    elseif self.activeTab == "shop" then
        self:drawShopContent(x, contentY, w, contentH, alpha, uiMx, uiMy)
    end

    -- Draw bottom bar if needed (for shop credits/search)
    if self.activeTab == "shop" then
        self:drawShopBottomBar(x, y, w, h, alpha)
    end
end

function StationWindow:drawSectionButtons(windowX, windowY, alpha, uiMx, uiMy)
    local topBarH = Theme.window.topBarHeight or 0
    local tabY = windowY + topBarH
    local tabWidth = self.width / #self.tabs

    self.tabButtons = {}

    local font = Theme.getFontBold(Theme.fonts.normal)
    for i, tabKey in ipairs(self.tabs) do
        local tabX = windowX + (i - 1) * tabWidth
        local isHovered = uiMx and uiMy and uiMx >= tabX and uiMx <= tabX + tabWidth 
                         and uiMy >= tabY and uiMy <= tabY + NAV_BUTTON_HEIGHT
        local isActive = self.activeTab == tabKey

        local baseColor = isActive and Theme.colors.hover or Theme.colors.surfaceAlt
        local hoverColor = Theme.colors.hover
        Theme.drawButton(tabX, tabY, tabWidth, NAV_BUTTON_HEIGHT, self.tabNames[tabKey], isHovered, baseColor, hoverColor, {
            font = font,
            textColor = Theme.colors.text,
        })

        table.insert(self.tabButtons, {
            x = tabX, y = tabY, w = tabWidth, h = NAV_BUTTON_HEIGHT,
            tabKey = tabKey
        })
    end

    local borderColor = Theme.colors.border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(windowX, tabY + NAV_BUTTON_HEIGHT, windowX + self.width, tabY + NAV_BUTTON_HEIGHT)
end

function StationWindow:drawQuestContent(x, y, w, h, alpha)
    -- Draw quest content using QuestWindow's method
    -- y is already positioned below tabs (contentY), so content should start there
    -- We'll skip the title since we have tabs, and start content directly
    local spacing = Theme.spacing
    local ECS = require('src.ecs')
    local QuestSystem
    local function getQuestSystem()
        if not QuestSystem then
            QuestSystem = require('src.systems.quest_system')
        end
        return QuestSystem
    end
    
    -- Get quests
    local questSys = getQuestSystem()
    local quests = {}
    if questSys and QuestWindow.currentStationId then
        questSys.initQuestBoard(QuestWindow.currentStationId)
        quests = questSys.getQuests(QuestWindow.currentStationId)
    end
    
    -- Draw station name if available
    local contentStartY = y + spacing.md
    if QuestWindow.currentStationId then
        local stationLabel = ECS.getComponent(QuestWindow.currentStationId, "StationLabel")
        if stationLabel and stationLabel[1] then
            local smallFont = Theme.getFont("xs")
            love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
            love.graphics.setFont(smallFont)
            love.graphics.print(stationLabel[1], x + spacing.md, contentStartY)
            contentStartY = contentStartY + smallFont:getHeight() + spacing.xs
        end
    end
    
    -- Draw quests
    local questStartY = contentStartY + (QuestWindow.currentStationId and spacing.xs or 0)
    local availableHeight = h - (questStartY - y) - spacing.md
    local questHeight = math.floor(availableHeight / math.max(3, #quests)) - spacing.xs
    
    for i, quest in ipairs(quests) do
        QuestWindow:drawQuest(x + spacing.md, questStartY + (i-1) * (questHeight + spacing.xs), w - spacing.md * 2, questHeight, quest, alpha, i)
    end
    
    -- Draw "no quests" message if empty
    if #quests == 0 then
        local font = Theme.getFont("sm")
        local centerY = y + h / 2
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.setFont(font)
        local questText = "No active quests available."
        local questTextW = font:getWidth(questText)
        love.graphics.print(questText, x + (w - questTextW) / 2, centerY - font:getHeight())
        
        local smallFont = Theme.getFont("xs")
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
        love.graphics.setFont(smallFont)
        local hintText = "Come back later for new missions!"
        local hintTextW = smallFont:getWidth(hintText)
        love.graphics.print(hintText, x + (w - hintTextW) / 2, centerY + spacing.xs)
    end
end

function StationWindow:drawShopContent(x, y, w, h, alpha, uiMx, uiMy)
    -- Draw shop content area (similar to ShopWindow's drawCargoContent pattern)
    local ECS = require('src.ecs')
    local padding = 12
    local contentX = x + 10
    local contentY = y + 8
    local contentW = w - 20
    local contentH = h - 16

    -- Get player cargo for unified list
    local EntityHelpers = require('src.entity_helpers')
    local droneId = EntityHelpers.getPlayerShip()
    local cargo = droneId and ECS.getComponent(droneId, "Cargo")
    
    -- Build unified item list
    ShopWindow:ensureItems()
    local unifiedList = buildUnifiedItemList(ShopWindow.items, cargo)
    
    -- Filter by search query
    local itemsList = {}
    local q = (ShopWindow.shopSearchQuery or ""):lower()
    for _, item in ipairs(unifiedList) do
        local name = (item.def.name or item.id):lower()
        if q == "" or name:find(q, 1, true) then
            table.insert(itemsList, item)
        end
    end

    -- Draw grid of items
    local slotSize = 72
    local slotPadding = 10
    local slotsPerRow = math.floor(contentW / (slotSize + slotPadding))
    if slotsPerRow < 1 then slotsPerRow = 1 end
    local mx, my = (uiMx or 0), (uiMy or 0)
    self.hoveredItemSlot = nil
    -- Track buy/sell button positions (recreated each frame)
    self.itemButtons = {}
    
    -- Increased height to accommodate text and buttons
    local slotTotalHeight = slotSize + 110
    
    for i, item in ipairs(itemsList) do
        local row = math.floor((i - 1) / slotsPerRow)
        local col = (i - 1) % slotsPerRow
        local slotX = contentX + col * (slotSize + slotPadding)
        local slotY = contentY + row * (slotTotalHeight + slotPadding)
        -- Check hover over the icon area for visual feedback
        local isHovered = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize
        -- Check hover over the full slot (including text area) for tooltip
        local isHoveredForTooltip = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotTotalHeight
        if isHoveredForTooltip then
            -- Format for tooltip compatibility (same as CargoWindow)
            self.hoveredItemSlot = {
                itemId = item.id,
                itemDef = item.def,
                count = item.playerCount or 0, -- Show player's count for tooltip
                mouseX = mx,
                mouseY = my
            }
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
            local UIUtils = require('src.ui.ui_utils')
            UIUtils.drawItemIcon(def, cx, cy, alpha, 1.0)
        end

        -- Draw name with smaller font and better spacing
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local labelY = slotY + slotSize + 6
        local label = (def and def.name) or item.id or ""
        
        -- Truncate long names to fit in slot width
        local font = love.graphics.getFont()
        local maxWidth = slotSize - 4
        if font:getWidth(label) > maxWidth then
            -- Truncate with ellipsis
            local truncated = label
            while font:getWidth(truncated .. "...") > maxWidth and #truncated > 1 do
                truncated = truncated:sub(1, #truncated - 1)
            end
            label = truncated .. "..."
        end
        
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(label, slotX, labelY, slotSize, "center")
        
        -- Draw quantities with better spacing (increased from 16 to 20)
        local infoY = labelY + 20
        local shopCount = item.shopCount or 0
        local playerCount = item.playerCount or 0
        local shopText = shopCount == -1 and "Shop: INF" or (shopCount > 0 and ("Shop: " .. shopCount) or "Shop: -")
        local playerText = "You: " .. playerCount
        
        -- Use tiny font for quantities to match name size
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        
        if shopCount == -1 or shopCount > 0 then
            local shopColor = Theme.colors.success or {0.1, 0.8, 0.5, 1}
            love.graphics.setColor(shopColor[1], shopColor[2], shopColor[3], alpha)
        else
            local mutedColor = Theme.colors.textSecondary or {0.5, 0.5, 0.5, 1}
            love.graphics.setColor(mutedColor[1], mutedColor[2], mutedColor[3], alpha)
        end
        love.graphics.printf(shopText, slotX, infoY, slotSize, "center")
        
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(playerText, slotX, infoY + 12, slotSize, "center")
        
        -- Draw price with spacing (using tiny font)
        local priceY = infoY + 24
        local price = (def and def.value) or 0
        local accent = Theme.colors.textAccent or {1, 0.8, 0.6, 1}
        love.graphics.setColor(accent[1], accent[2], accent[3], alpha)
        love.graphics.printf(string.format("%d c", price), slotX, priceY, slotSize, "center")
        
        -- Draw Buy/Sell buttons
        local buttonY = priceY + 18
        local buttonH = 22
        local buttonW = (slotSize - 4) / 2
        local buttonSpacing = 2
        
        -- Buy button
        local buyButtonX = slotX + 2
        local canBuy = (shopCount == -1 or shopCount > 0) and price > 0
        local buyHovered = canBuy and mx >= buyButtonX and mx <= buyButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        
        if canBuy then
            local buyColor = buyHovered and (Theme.colors.successHover or {0.2, 0.9, 0.6, 1}) or (Theme.colors.success or {0.1, 0.8, 0.5, 1})
            love.graphics.setColor(buyColor[1], buyColor[2], buyColor[3], alpha)
            love.graphics.rectangle('fill', buyButtonX, buttonY, buttonW, buttonH, corner, corner)
            love.graphics.setColor(border[1], border[2], border[3], 0.8 * alpha)
            love.graphics.rectangle('line', buyButtonX, buttonY, buttonW, buttonH, corner, corner)
        else
            love.graphics.setColor(bg[1], bg[2], bg[3], 0.5 * alpha)
            love.graphics.rectangle('fill', buyButtonX, buttonY, buttonW, buttonH, corner, corner)
            love.graphics.setColor(border[1], border[2], border[3], 0.3 * alpha)
            love.graphics.rectangle('line', buyButtonX, buttonY, buttonW, buttonH, corner, corner)
        end
        
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local buyTextColor = canBuy and Theme.colors.text or Theme.colors.textSecondary
        love.graphics.setColor(buyTextColor[1], buyTextColor[2], buyTextColor[3], alpha)
        love.graphics.printf("BUY", buyButtonX, buttonY + 4, buttonW, "center")
        
        -- Store buy button
        self.itemButtons["buy_" .. i] = {
            x = buyButtonX,
            y = buttonY,
            w = buttonW,
            h = buttonH,
            item = item,
            enabled = canBuy
        }
        
        -- Sell button
        local sellButtonX = slotX + buttonW + buttonSpacing + 2
        local canSell = playerCount > 0
        local sellPrice = math.floor(price * 0.5)
        local sellHovered = canSell and mx >= sellButtonX and mx <= sellButtonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        
        if canSell then
            local sellColor = sellHovered and (Theme.colors.accentHover or {0.3, 0.5, 0.9, 1}) or (Theme.colors.accent or {0.2, 0.4, 0.8, 1})
            love.graphics.setColor(sellColor[1], sellColor[2], sellColor[3], alpha)
            love.graphics.rectangle('fill', sellButtonX, buttonY, buttonW, buttonH, corner, corner)
            love.graphics.setColor(border[1], border[2], border[3], 0.8 * alpha)
            love.graphics.rectangle('line', sellButtonX, buttonY, buttonW, buttonH, corner, corner)
        else
            love.graphics.setColor(bg[1], bg[2], bg[3], 0.5 * alpha)
            love.graphics.rectangle('fill', sellButtonX, buttonY, buttonW, buttonH, corner, corner)
            love.graphics.setColor(border[1], border[2], border[3], 0.3 * alpha)
            love.graphics.rectangle('line', sellButtonX, buttonY, buttonW, buttonH, corner, corner)
        end
        
        local sellTextColor = canSell and Theme.colors.text or Theme.colors.textSecondary
        love.graphics.setColor(sellTextColor[1], sellTextColor[2], sellTextColor[3], alpha)
        love.graphics.printf("SELL", sellButtonX, buttonY + 4, buttonW, "center")
        
        -- Store sell button
        self.itemButtons["sell_" .. i] = {
            x = sellButtonX,
            y = buttonY,
            w = buttonW,
            h = buttonH,
            item = item,
            enabled = canSell,
            sellPrice = sellPrice
        }
    end
end

function StationWindow:drawShopBottomBar(windowX, windowY, width, height, alpha)
    local ECS = require('src.ecs')
    local bottomBarH = Theme.window.bottomBarHeight or 36
    local x = windowX
    local y = windowY + height - bottomBarH
    local w = width
    local h = bottomBarH
    local padding = 12

    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local fontH = love.graphics.getFont():getHeight()

    -- Credits
    local pilotId = (require('src.entity_helpers').getPlayerPilot())
    local wallet = pilotId and ECS.getComponent(pilotId, "Wallet")
    local credits = wallet and wallet.credits or 0
    local coinSize = fontH + 6
    local coinX = x + padding + coinSize / 2
    local coinY = y + bottomBarH / 2
    
    -- Draw universal credit icon
    UIUtils.drawCreditIcon(coinX, coinY, coinSize, alpha)
    
    -- Draw credits amount next to icon
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.print(string.format('%d', credits), x + padding + coinSize + 8, y + (bottomBarH - fontH) / 2)

    -- Search box on right
    local searchW = 260
    local searchH = 28
    local searchX = x + w - searchW - padding
    local searchY = y + (bottomBarH - searchH) / 2
    self.shopSearchRect = { x = searchX, y = searchY, w = searchW, h = searchH }
    local bg = Theme.colors.surface
    local border = Theme.colors.border
    local corner = Theme.window.cornerRadius or 0
    if ShopWindow.searchFocused then
        local focusBg = Theme.colors.surfaceAlt or Theme.colors.surface
        love.graphics.setColor(focusBg[1], focusBg[2], focusBg[3], 0.95 * alpha)
        love.graphics.rectangle('fill', searchX - 1, searchY - 1, searchW + 2, searchH + 2, corner, corner)
    end
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.95 * alpha)
    love.graphics.rectangle('fill', searchX, searchY, searchW, searchH, corner, corner)
    love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
    love.graphics.rectangle('line', searchX, searchY, searchW, searchH, corner, corner)
    local placeholder = "Search..."
    local query = ShopWindow.shopSearchQuery or ""
    local showPlaceholder = query == "" and not ShopWindow.searchFocused
    love.graphics.setScissor(searchX + 8, searchY, searchW - 16, searchH)
    if showPlaceholder then
        local tc = Theme.colors.textSecondary
        love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * alpha)
        love.graphics.printf(placeholder, searchX + 8, searchY + 6, searchW - 16, "left")
    else
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.printf(query, searchX + 8, searchY + 6, searchW - 16, "left")
        if ShopWindow.searchFocused then
            local caretX = searchX + 8 + love.graphics.getFont():getWidth(query)
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.6 * alpha)
            love.graphics.line(caretX, searchY + 8, caretX, searchY + searchH - 8)
        end
    end
    love.graphics.setScissor()
end

function StationWindow:mousepressed(x, y, button)
    WindowBase.mousepressed(self, x, y, button)
    if not self:getOpen() then return true end
    if self.isDragging then return true end

    -- Handle tab clicks
    if self.tabButtons then
        for _, tabButton in ipairs(self.tabButtons) do
            if x >= tabButton.x and x <= tabButton.x + tabButton.w 
               and y >= tabButton.y and y <= tabButton.y + tabButton.h then
                self.activeTab = tabButton.tabKey
                return true
            end
        end
    end

    -- Delegate to active tab's handlers
    if self.activeTab == "quest" then
        -- Temporarily set QuestWindow position and dimensions for mouse handling
        local oldPos = QuestWindow.position
        local oldHeight = QuestWindow.height
        local oldWidth = QuestWindow.width
        
        QuestWindow.position = self.position
        QuestWindow.height = self.height
        QuestWindow.width = self.width
        QuestWindow.isOpen = true
        
        -- QuestWindow expects screen coordinates but we get UI coordinates
        -- The coordinates are already in UI space, so we pass them directly
        -- But QuestWindow internally calls Scaling.toUI again, so we need to handle this
        local result = false
        
        -- Check quest buttons manually since QuestWindow's coordinate system doesn't match
        if button == 1 and QuestWindow.currentStationId then
            local QuestSystem
            local function getQuestSystem()
                if not QuestSystem then
                    QuestSystem = require('src.systems.quest_system')
                end
                return QuestSystem
            end
            
            local questSys = getQuestSystem()
            if questSys then
                local ECS = require('src.ecs')
                local spacing = Theme.spacing
                local topBarH = Theme.window.topBarHeight or 0
                local contentStartY = self.position.y + topBarH + NAV_BUTTON_HEIGHT + spacing.md
                
                -- Check for station label offset
                local stationLabel = ECS.getComponent(QuestWindow.currentStationId, "StationLabel")
                if stationLabel and stationLabel[1] then
                    local smallFont = Theme.getFont("xs")
                    contentStartY = contentStartY + smallFont:getHeight() + spacing.xs
                end
                
                local quests = questSys.getQuests(QuestWindow.currentStationId)
                local availableHeight = self.height - topBarH - NAV_BUTTON_HEIGHT - (contentStartY - self.position.y) - spacing.md
                local questHeight = math.floor(availableHeight / math.max(3, #quests)) - spacing.xs
                
                for i, quest in ipairs(quests) do
                    local qx = self.position.x + spacing.md
                    local qy = contentStartY + (i-1) * (questHeight + spacing.xs)
                    local qw = self.width - spacing.md * 2
                    
                    local buttonW = 80
                    local buttonH = 22
                    local buttonX = qx + qw - buttonW - spacing.sm
                    local buttonY = qy + spacing.xs
                    
                    if x >= buttonX and x <= buttonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
                        if not quest.accepted then
                            questSys.acceptQuest(QuestWindow.currentStationId, quest.id)
                            result = true
                            break
                        elseif quest.completed then
                            if questSys.turnInQuest(QuestWindow.currentStationId, quest.id) then
                                local Notifications = require('src.ui.notifications')
                                Notifications.addNotification{
                                    type = 'quest',
                                    text = string.format("Quest completed! +%d credits", quest.reward),
                                    timer = 3.0
                                }
                                result = true
                                break
                            end
                        end
                    end
                end
            end
        end
        
        QuestWindow.position = oldPos
        QuestWindow.height = oldHeight
        QuestWindow.width = oldWidth
        QuestWindow.isOpen = false
        
        return result
    elseif self.activeTab == "shop" then
        -- Handle shop interactions
        if self.shopSearchRect and x >= self.shopSearchRect.x and x <= self.shopSearchRect.x + self.shopSearchRect.w
           and y >= self.shopSearchRect.y and y <= self.shopSearchRect.y + self.shopSearchRect.h then
            ShopWindow.searchFocused = true
            return true
        else
            ShopWindow.searchFocused = false
        end

        -- Handle Buy/Sell button clicks
        if self.itemButtons and button == 1 then
            for buttonId, btn in pairs(self.itemButtons) do
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h and btn.enabled then
                    local EntityHelpers = require('src.entity_helpers')
                    local ECS = require('src.ecs')
                    local Notifications = require('src.ui.notifications')
                    local pilotId = EntityHelpers.getPlayerPilot()
                    local droneId = EntityHelpers.getPlayerShip()
                    local wallet = pilotId and ECS.getComponent(pilotId, "Wallet")
                    local cargo = droneId and ECS.getComponent(droneId, "Cargo")
                    
                    if buttonId:match("^buy_") then
                        -- Buy action
                        local selected = btn.item
                        local price = (selected.def and selected.def.value) or 0
                        if wallet and wallet.credits and wallet.credits >= price then
                            if cargo and cargo.addItem and cargo:canAddItem(selected.id, 1) then
                                wallet.credits = wallet.credits - price
                                cargo:addItem(selected.id, 1)
                                Notifications.addItemNotification(selected.id, 1)
                            else
                                Notifications.addNotification{ type = 'item', text = 'Not enough cargo space', timer = 2 }
                            end
                        else
                            Notifications.addNotification{ type = 'item', text = 'Not enough credits', timer = 2 }
                        end
                        return true
                    elseif buttonId:match("^sell_") then
                        -- Sell action
                        local selected = btn.item
                        local sellPrice = btn.sellPrice or math.floor((selected.def and selected.def.value or 0) * 0.5)
                        if cargo and cargo.removeItem then
                            local removed = cargo:removeItem(selected.id, 1)
                            if removed then
                                if wallet then wallet.credits = (wallet.credits or 0) + sellPrice end
                                local itemName = (selected.def and selected.def.name) or selected.id
                                Notifications.addNotification{ type = 'item', text = string.format('Sold: %s (+%d c)', itemName, sellPrice), timer = 2 }
                            else
                                Notifications.addNotification{ type = 'item', text = 'Nothing to sell', timer = 2 }
                            end
                        else
                            Notifications.addNotification{ type = 'item', text = 'You don\'t have this item', timer = 2 }
                        end
                        return true
                    end
                end
            end
        end
    end

    return false
end

function StationWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
    if self.activeTab == "quest" then
        local oldPos = QuestWindow.position
        QuestWindow.position = self.position
        QuestWindow.isOpen = true
        QuestWindow:mousereleased(x, y, button)
        QuestWindow.position = oldPos
        QuestWindow.isOpen = false
    end
end

function StationWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
    if self.activeTab == "quest" then
        local oldPos = QuestWindow.position
        QuestWindow.position = self.position
        QuestWindow.isOpen = true
        QuestWindow:mousemoved(x, y, dx, dy)
        QuestWindow.position = oldPos
        QuestWindow.isOpen = false
    end
end

function StationWindow:keypressed(key)
    if self.activeTab == "shop" then
        if not ShopWindow.searchFocused then return false end
        if key == 'backspace' then
            local q = ShopWindow.shopSearchQuery or ''
            ShopWindow.shopSearchQuery = q:sub(1, math.max(0, #q - 1))
            return true
        elseif key == 'escape' then
            ShopWindow.searchFocused = false
            return true
        elseif key == 'return' or key == 'kpenter' then
            ShopWindow.searchFocused = false
            return true
        end
    end
    return false
end

function StationWindow:textinput(t)
    if self.activeTab == "shop" and ShopWindow.searchFocused then
        t = t or ''
        ShopWindow.shopSearchQuery = (ShopWindow.shopSearchQuery or '') .. t
        if #ShopWindow.shopSearchQuery > 64 then
            ShopWindow.shopSearchQuery = ShopWindow.shopSearchQuery:sub(1,64)
        end
        return true
    end
    return false
end

return StationWindow

