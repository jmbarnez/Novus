--- Station Window HUD Widget
--- Fullscreen window with shop and quest tabs

local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local Shop = require("game.shop")
local Quests = require("game.quests")
local StationUI = require("game.hud.station_state")
local ItemIcons = require("game.item_icons")
local Inventory = require("game.inventory")
local Items = require("game.items")

local pointInRect = Rect.pointInRect

local function makeStationWindow()
    local self = {
        windowFrame = WindowFrame.new(),
        scrollY = 0,
        hoveredItem = nil,
        hoveredQuest = nil,
        quantities = {},    -- Per-item quantity inputs
        notification = nil, -- { text, color, timer }
    }

    -- Constants
    local WINDOW_W = 650
    local WINDOW_H = 480
    local HEADER_H = 32
    local TAB_H = 28
    local CONTENT_PAD = 12

    -- State access
    local function getStationUI(ctx)
        local world = ctx and ctx.world
        return world and world:getResource("station_ui")
    end

    local function getUiCapture(ctx)
        local world = ctx and ctx.world
        return world and world:getResource("ui_capture")
    end

    local function setOpen(ctx, open, stationEntity)
        local stationUi = getStationUI(ctx)
        if not stationUi then return end

        if open then
            local world = ctx and ctx.world
            -- Only generate new quests if there are no existing quests (preserves progress)
            local existingQuests = stationUi.quests or {}
            local quests = existingQuests
            if #existingQuests == 0 then
                local worldSeed = world and world:getResource("world_seed") or os.time()
                quests = Quests.generate(worldSeed + 12345, 3) -- Max 3 quests available
            end
            StationUI.open(stationUi, stationEntity, quests)
            -- Reset quantities
            self.quantities = {}
            -- Bring window to front
            if ctx.hud then
                ctx.hud:bringToFront(self)
            end
        else
            StationUI.close(stationUi)
        end
    end

    -- Layout computation
    local function computeLayout(ctx)
        local screenW = ctx and ctx.screenW or 800
        local screenH = ctx and ctx.screenH or 600

        local x = math.floor((screenW - WINDOW_W) / 2)
        local y = math.floor((screenH - WINDOW_H) / 2)

        -- Let WindowFrame handle position (for dragging)
        local bounds = self.windowFrame:compute(ctx, WINDOW_W, WINDOW_H, {
            headerH = HEADER_H,
            closeSize = 18,
            closePad = 8,
        })

        -- Tab bar
        local tabY = bounds.y + HEADER_H
        local tabW = WINDOW_W / 2
        bounds.shopTab = { x = bounds.x, y = tabY, w = tabW, h = TAB_H }
        bounds.questsTab = { x = bounds.x + tabW, y = tabY, w = tabW, h = TAB_H }

        -- Content area
        local contentY = tabY + TAB_H + CONTENT_PAD
        local contentH = WINDOW_H - HEADER_H - TAB_H - CONTENT_PAD * 2
        bounds.contentRect = { x = bounds.x + CONTENT_PAD, y = contentY, w = WINDOW_W - CONTENT_PAD * 2, h = contentH }

        return bounds
    end

    -- Get quantity for an item
    local function getQuantity(itemId)
        return self.quantities[itemId] or 1
    end

    -- Set quantity for an item
    local function setQuantity(itemId, qty)
        qty = math.max(1, math.min(99, qty or 1))
        self.quantities[itemId] = qty
    end

    -- Show notification
    local function showNotification(text, isSuccess)
        self.notification = {
            text = text,
            isSuccess = isSuccess,
            timer = 2.0, -- seconds to display
        }
    end

    -- Get how much of an item the player has
    local function getPlayerStock(ctx, itemId)
        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship
        if not ship or not ship.cargo_hold then return 0 end

        local itemDef = Items.get(itemId)
        local unitVolume = (itemDef and itemDef.unitVolume) or 1
        local total = 0

        for _, slot in ipairs(ship.cargo_hold.slots) do
            if slot.id == itemId and slot.volume then
                total = total + slot.volume
            end
        end

        return math.floor(total / unitVolume)
    end

    -- Draw shop tab content
    local function drawShopContent(ctx, rect)
        local items = Shop.getItems()
        local itemH = 56
        local pad = 6

        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)

        for i, item in ipairs(items) do
            local iy = rect.y + (i - 1) * itemH + pad - self.scrollY

            if iy + itemH > rect.y and iy < rect.y + rect.h then
                local itemRect = { x = rect.x + pad, y = iy, w = rect.w - pad * 2, h = itemH - pad }
                local mx, my = love.mouse.getPosition()
                local hovered = pointInRect(mx, my, itemRect)

                -- Background
                love.graphics.setColor(0.12, 0.16, 0.24, hovered and 0.95 or 0.75)
                love.graphics.rectangle("fill", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 4)

                -- Border
                love.graphics.setColor(0.35, 0.45, 0.60, hovered and 0.9 or 0.5)
                love.graphics.setLineWidth(hovered and 2 or 1)
                love.graphics.rectangle("line", itemRect.x, itemRect.y, itemRect.w, itemRect.h, 4)

                -- Item icon (using realistic design)
                local iconSize = 36
                local iconX = itemRect.x + 8
                local iconY = itemRect.y + (itemRect.h - iconSize) / 2
                ItemIcons.draw(item.id, iconX, iconY, iconSize, iconSize)

                -- Item name
                local font = love.graphics.getFont()
                local nameX = iconX + iconSize + 12
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print(item.name or item.id, nameX, itemRect.y + 8)

                -- Price
                local priceText = string.format("%d cr each", item.price)
                love.graphics.setColor(0.85, 0.80, 0.40, 0.9)
                love.graphics.print(priceText, nameX, itemRect.y + 26)

                -- Quantity controls
                local qty = getQuantity(item.id)
                local qtyX = itemRect.x + itemRect.w - 230
                local qtyY = itemRect.y + 12

                -- Minus button
                local minusBtnRect = { x = qtyX, y = qtyY, w = 22, h = 22 }
                local minusHover = pointInRect(mx, my, minusBtnRect)
                love.graphics.setColor(0.25, 0.30, 0.40, minusHover and 1.0 or 0.8)
                love.graphics.rectangle("fill", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                love.graphics.setColor(0.50, 0.60, 0.75, 0.9)
                love.graphics.rectangle("line", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print("-", minusBtnRect.x + 7, minusBtnRect.y + 3)

                -- Quantity display
                local qtyText = tostring(qty)
                local qtyTw = font:getWidth(qtyText)
                love.graphics.setColor(0.10, 0.14, 0.22, 0.9)
                love.graphics.rectangle("fill", qtyX + 26, qtyY, 36, 22, 3)
                love.graphics.setColor(0.50, 0.60, 0.75, 0.7)
                love.graphics.rectangle("line", qtyX + 26, qtyY, 36, 22, 3)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print(qtyText, qtyX + 26 + (36 - qtyTw) / 2, qtyY + 3)

                -- Plus button
                local plusBtnRect = { x = qtyX + 66, y = qtyY, w = 22, h = 22 }
                local plusHover = pointInRect(mx, my, plusBtnRect)
                love.graphics.setColor(0.25, 0.30, 0.40, plusHover and 1.0 or 0.8)
                love.graphics.rectangle("fill", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                love.graphics.setColor(0.50, 0.60, 0.75, 0.9)
                love.graphics.rectangle("line", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print("+", plusBtnRect.x + 6, plusBtnRect.y + 3)

                -- Buy button
                local buyBtnRect = { x = qtyX + 96, y = qtyY, w = 50, h = 22 }
                local buyHover = pointInRect(mx, my, buyBtnRect)
                love.graphics.setColor(0.15, 0.40, 0.25, buyHover and 1.0 or 0.8)
                love.graphics.rectangle("fill", buyBtnRect.x, buyBtnRect.y, buyBtnRect.w, buyBtnRect.h, 3)
                love.graphics.setColor(0.30, 0.70, 0.45, 0.9)
                love.graphics.rectangle("line", buyBtnRect.x, buyBtnRect.y, buyBtnRect.w, buyBtnRect.h, 3)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print("Buy", buyBtnRect.x + 13, buyBtnRect.y + 3)

                -- Sell button (only show if player has items)
                local stock = getPlayerStock(ctx, item.id)
                local sellBtnRect = { x = qtyX + 152, y = qtyY, w = 50, h = 22 }
                if stock >= qty then
                    local sellHover = pointInRect(mx, my, sellBtnRect)
                    love.graphics.setColor(0.45, 0.25, 0.15, sellHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", sellBtnRect.x, sellBtnRect.y, sellBtnRect.w, sellBtnRect.h, 3)
                    love.graphics.setColor(0.75, 0.45, 0.30, 0.9)
                    love.graphics.rectangle("line", sellBtnRect.x, sellBtnRect.y, sellBtnRect.w, sellBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.print("Sell", sellBtnRect.x + 11, sellBtnRect.y + 3)
                else
                    -- Disabled sell button
                    love.graphics.setColor(0.20, 0.20, 0.20, 0.5)
                    love.graphics.rectangle("fill", sellBtnRect.x, sellBtnRect.y, sellBtnRect.w, sellBtnRect.h, 3)
                    love.graphics.setColor(0.35, 0.35, 0.35, 0.5)
                    love.graphics.rectangle("line", sellBtnRect.x, sellBtnRect.y, sellBtnRect.w, sellBtnRect.h, 3)
                    love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                    love.graphics.print("Sell", sellBtnRect.x + 11, sellBtnRect.y + 3)
                end

                -- Stock indicator
                if stock > 0 then
                    local stockText = string.format("x%d", stock)
                    love.graphics.setColor(0.6, 0.8, 0.6, 0.8)
                    love.graphics.print(stockText, nameX + 80, itemRect.y + 26)
                end
            end
        end

        love.graphics.setScissor()
        love.graphics.setLineWidth(1)
    end

    -- Draw quests tab content
    local function drawQuestsContent(ctx, rect, stationUi)
        local quests = stationUi and stationUi.quests or {}
        local questH = 60
        local pad = 8

        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)

        if #quests == 0 then
            love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
            love.graphics.print("No quests available", rect.x + 10, rect.y + 10)
        else
            for i, quest in ipairs(quests) do
                local qy = rect.y + (i - 1) * questH + pad - self.scrollY

                if qy + questH > rect.y and qy < rect.y + rect.h then
                    local questRect = { x = rect.x + pad, y = qy, w = rect.w - pad * 2, h = questH - pad }
                    local mx, my = love.mouse.getPosition()
                    local hovered = pointInRect(mx, my, questRect)

                    -- Background
                    local bgAlpha = 0.7
                    if quest.completed then
                        love.graphics.setColor(0.15, 0.35, 0.20, bgAlpha)
                    elseif quest.accepted then
                        love.graphics.setColor(0.25, 0.25, 0.15, bgAlpha)
                    else
                        love.graphics.setColor(0.15, 0.20, 0.28, hovered and 0.9 or bgAlpha)
                    end
                    love.graphics.rectangle("fill", questRect.x, questRect.y, questRect.w, questRect.h, 4)

                    -- Border
                    love.graphics.setColor(0.40, 0.50, 0.65, hovered and 0.9 or 0.5)
                    love.graphics.setLineWidth(hovered and 2 or 1)
                    love.graphics.rectangle("line", questRect.x, questRect.y, questRect.w, questRect.h, 4)

                    -- Quest description
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.print(quest.description, questRect.x + 10, questRect.y + 8)

                    -- Progress
                    local progress = string.format("%d / %d", quest.current or 0, quest.amount or 0)
                    if quest.type == "collect_resource" then
                        progress = progress .. " m3"
                    end
                    love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
                    love.graphics.print(progress, questRect.x + 10, questRect.y + 26)

                    -- Reward
                    local reward = string.format("Reward: %d cr", quest.reward or 0)
                    love.graphics.setColor(0.90, 0.85, 0.40, 0.9)
                    love.graphics.print(reward, questRect.x + 120, questRect.y + 26)

                    -- Status / Accept button
                    local btnX = questRect.x + questRect.w - 80
                    local btnY = questRect.y + 15
                    local btnW = 70
                    local btnH = 22

                    if quest.completed then
                        love.graphics.setColor(0.30, 0.80, 0.40, 0.9)
                        love.graphics.print("DONE", btnX + 15, btnY + 3)
                    elseif quest.accepted then
                        love.graphics.setColor(0.80, 0.75, 0.30, 0.9)
                        love.graphics.print("ACTIVE", btnX + 8, btnY + 3)
                    else
                        local btnHovered = pointInRect(mx, my, { x = btnX, y = btnY, w = btnW, h = btnH })
                        love.graphics.setColor(0.20, 0.50, 0.35, btnHovered and 1.0 or 0.8)
                        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
                        love.graphics.setColor(0.30, 0.80, 0.50, 0.9)
                        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 3)
                        love.graphics.setColor(1, 1, 1, 0.95)
                        love.graphics.print("Accept", btnX + 12, btnY + 3)
                    end
                end
            end
        end

        love.graphics.setScissor()
        love.graphics.setLineWidth(1)
    end

    -- Interface: hitTest
    function self.hitTest(ctx, x, y)
        local stationUi = getStationUI(ctx)
        return stationUi and stationUi.open or false
    end

    -- Interface: draw
    function self.draw(ctx)
        local stationUi = getStationUI(ctx)
        if not stationUi or not stationUi.open then return end

        local theme = (ctx and ctx.theme) or Theme
        local bounds = computeLayout(ctx)

        -- Window frame
        self.windowFrame:draw(ctx, bounds, {
            title = "STATION",
            headerAlpha = 0.55,
            headerLineAlpha = 0.4,
            owner = self,
        })

        -- Tabs
        local activeTab = stationUi.activeTab or "shop"

        -- Shop tab
        local shopActive = activeTab == "shop"
        love.graphics.setColor(0.15, 0.20, 0.28, shopActive and 0.9 or 0.5)
        love.graphics.rectangle("fill", bounds.shopTab.x, bounds.shopTab.y, bounds.shopTab.w, bounds.shopTab.h)
        love.graphics.setColor(0.40, 0.50, 0.65, 0.7)
        love.graphics.rectangle("line", bounds.shopTab.x, bounds.shopTab.y, bounds.shopTab.w, bounds.shopTab.h)
        love.graphics.setColor(1, 1, 1, shopActive and 1.0 or 0.6)
        local shopText = "SHOP"
        local font = love.graphics.getFont()
        love.graphics.print(shopText, bounds.shopTab.x + (bounds.shopTab.w - font:getWidth(shopText)) / 2,
            bounds.shopTab.y + 6)

        -- Quests tab
        local questsActive = activeTab == "quests"
        love.graphics.setColor(0.15, 0.20, 0.28, questsActive and 0.9 or 0.5)
        love.graphics.rectangle("fill", bounds.questsTab.x, bounds.questsTab.y, bounds.questsTab.w, bounds.questsTab.h)
        love.graphics.setColor(0.40, 0.50, 0.65, 0.7)
        love.graphics.rectangle("line", bounds.questsTab.x, bounds.questsTab.y, bounds.questsTab.w, bounds.questsTab.h)
        love.graphics.setColor(1, 1, 1, questsActive and 1.0 or 0.6)
        local questsText = "QUESTS"
        love.graphics.print(questsText, bounds.questsTab.x + (bounds.questsTab.w - font:getWidth(questsText)) / 2,
            bounds.questsTab.y + 6)

        -- Content
        if activeTab == "shop" then
            drawShopContent(ctx, bounds.contentRect)
        else
            drawQuestsContent(ctx, bounds.contentRect, stationUi)
        end

        -- Draw notification
        if self.notification and self.notification.timer and self.notification.timer > 0 then
            local notif = self.notification
            local alpha = math.min(1, notif.timer / 0.5) -- Fade out in last 0.5 seconds
            local font = love.graphics.getFont()
            local text = notif.text
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local nx = bounds.x + (WINDOW_W - tw) / 2
            local ny = bounds.y + WINDOW_H - 50

            -- Background
            love.graphics.setColor(0.05, 0.10, 0.15, 0.9 * alpha)
            love.graphics.rectangle("fill", nx - 12, ny - 6, tw + 24, th + 12, 4)

            -- Border and text color based on success/failure
            if notif.isSuccess then
                love.graphics.setColor(0.30, 0.80, 0.50, 0.9 * alpha)
                love.graphics.rectangle("line", nx - 12, ny - 6, tw + 24, th + 12, 4)
                love.graphics.setColor(0.40, 1.00, 0.60, alpha)
            else
                love.graphics.setColor(0.80, 0.40, 0.30, 0.9 * alpha)
                love.graphics.rectangle("line", nx - 12, ny - 6, tw + 24, th + 12, 4)
                love.graphics.setColor(1.00, 0.50, 0.40, alpha)
            end
            love.graphics.print(text, nx, ny)

            -- Decrement timer (approximate based on 60fps)
            notif.timer = notif.timer - (1 / 60)
            if notif.timer <= 0 then
                self.notification = nil
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Interface: keypressed
    function self.keypressed(ctx, key)
        local stationUi = getStationUI(ctx)

        -- Open station window on E when near station
        if key == "e" then
            if stationUi and stationUi.open then
                setOpen(ctx, false)
                return true
            elseif ctx.interactionPrompt and ctx.interactionPrompt.entity then
                setOpen(ctx, true, ctx.interactionPrompt.entity)
                return true
            end
        end

        if not stationUi or not stationUi.open then
            return false
        end

        if key == "escape" then
            setOpen(ctx, false)
            return true
        end

        -- Don't block other keys - allow other windows to handle them
        return false
    end

    -- Interface: mousepressed
    function self.mousepressed(ctx, x, y, button)
        local stationUi = getStationUI(ctx)
        if not stationUi or not stationUi.open then return false end

        local bounds = computeLayout(ctx)

        -- Bring to front when clicked
        if pointInRect(x, y, bounds) and ctx.hud then
            ctx.hud:bringToFront(self)
        end

        -- Window frame (close button, drag header)
        local consumed, closeHit, headerDrag = self.windowFrame:mousepressed(ctx, bounds, x, y, button)
        if closeHit then
            setOpen(ctx, false)
            return true
        end
        if headerDrag then
            return true
        end

        -- Tab clicks
        if button == 1 then
            if pointInRect(x, y, bounds.shopTab) then
                StationUI.setTab(stationUi, "shop")
                self.scrollY = 0
                return true
            elseif pointInRect(x, y, bounds.questsTab) then
                StationUI.setTab(stationUi, "quests")
                self.scrollY = 0
                return true
            end

            -- Shop item button clicks
            if stationUi.activeTab == "shop" and pointInRect(x, y, bounds.contentRect) then
                local items = Shop.getItems()
                local itemH = 56
                local pad = 6

                -- Get player and ship for transactions
                local player = ctx.world and ctx.world:getResource("player")
                local ship = player and player.pilot and player.pilot.ship

                for i, item in ipairs(items) do
                    local iy = bounds.contentRect.y + (i - 1) * itemH + pad - self.scrollY
                    local itemRect = {
                        x = bounds.contentRect.x + pad,
                        y = iy,
                        w = bounds.contentRect.w - pad * 2,
                        h =
                            itemH - pad
                    }

                    if iy + itemH > bounds.contentRect.y and iy < bounds.contentRect.y + bounds.contentRect.h then
                        local qtyX = itemRect.x + itemRect.w - 230
                        local qtyY = iy + 12

                        -- Minus button
                        if pointInRect(x, y, { x = qtyX, y = qtyY, w = 22, h = 22 }) then
                            setQuantity(item.id, getQuantity(item.id) - 1)
                            return true
                        end

                        -- Plus button
                        if pointInRect(x, y, { x = qtyX + 66, y = qtyY, w = 22, h = 22 }) then
                            setQuantity(item.id, getQuantity(item.id) + 1)
                            return true
                        end

                        -- Buy button
                        if pointInRect(x, y, { x = qtyX + 96, y = qtyY, w = 50, h = 22 }) then
                            local qty = getQuantity(item.id)
                            if player and ship then
                                local success, msg = Shop.buyItem(player, ship, item.id, qty)
                                if success then
                                    showNotification("Bought " .. qty .. " " .. (item.name or item.id), true)
                                else
                                    showNotification(msg or "Purchase failed", false)
                                end
                            end
                            return true
                        end

                        -- Sell button (only works if player has enough)
                        if pointInRect(x, y, { x = qtyX + 152, y = qtyY, w = 50, h = 22 }) then
                            local qty = getQuantity(item.id)
                            local stock = getPlayerStock(ctx, item.id)
                            if player and ship and stock >= qty then
                                local success, msg = Shop.sellItem(player, ship, item.id, qty)
                                if success then
                                    showNotification("Sold " .. qty .. " " .. (item.name or item.id), true)
                                else
                                    showNotification(msg or "Sale failed", false)
                                end
                            end
                            return true
                        end
                    end
                end
            end

            -- Quest accept buttons
            if stationUi.activeTab == "quests" and pointInRect(x, y, bounds.contentRect) then
                local quests = stationUi.quests or {}
                local questH = 60
                local pad = 8
                for i, quest in ipairs(quests) do
                    if not quest.accepted and not quest.completed then
                        local qy = bounds.contentRect.y + (i - 1) * questH + pad - self.scrollY
                        local btnX = bounds.contentRect.x + bounds.contentRect.w - pad * 2 - 80
                        local btnY = qy + 15
                        if pointInRect(x, y, { x = btnX, y = btnY, w = 70, h = 22 }) then
                            Quests.accept(stationUi.quests, quest.id)
                            return true
                        end
                    end
                end
            end
        end

        return pointInRect(x, y, bounds)
    end

    -- Interface: mousereleased
    function self.mousereleased(ctx, x, y, button)
        local stationUi = getStationUI(ctx)
        if not stationUi or not stationUi.open then return false end

        if self.windowFrame:mousereleased(ctx, x, y, button) then
            return true
        end

        return false
    end

    -- Interface: mousemoved
    function self.mousemoved(ctx, x, y, dx, dy)
        local stationUi = getStationUI(ctx)
        if not stationUi or not stationUi.open then return false end

        if self.windowFrame:mousemoved(ctx, x, y, dx, dy) then
            return true
        end

        return false
    end

    -- Interface: wheelmoved
    function self.wheelmoved(ctx, x, y)
        local stationUi = getStationUI(ctx)
        if not stationUi or not stationUi.open then return false end

        self.scrollY = math.max(0, self.scrollY - y * 30)
        return true
    end

    return self
end

return makeStationWindow()
