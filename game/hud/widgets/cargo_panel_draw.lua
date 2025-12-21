--- Cargo Panel Drawing functions
local M = {}

local Theme = require("game.theme")
local Items = require("game.items")
local ItemIcons = require("game.item_icons")

--- Draw the credit icon (stylized coin with C symbol)
---@param cx number Center X
---@param cy number Center Y
---@param size number Icon size
local function drawCreditIcon(cx, cy, size)
    local r = size * 0.5

    -- Outer coin ring
    love.graphics.push("all")
    love.graphics.setColor(0.85, 0.70, 0.25, 0.3)
    love.graphics.circle("fill", cx + 2, cy + 2, r) -- shadow

    love.graphics.setColor(0.95, 0.80, 0.30, 0.95)
    love.graphics.circle("fill", cx, cy, r)

    -- Inner ring
    love.graphics.setColor(0.80, 0.65, 0.20, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r * 0.75)

    -- Center "C" shape
    love.graphics.setColor(0.40, 0.30, 0.10, 0.9)
    love.graphics.setLineWidth(2.5)
    love.graphics.arc("line", "open", cx, cy, r * 0.45, math.pi * 0.3, math.pi * 1.7)

    -- Highlight
    love.graphics.setColor(1, 1, 0.85, 0.4)
    love.graphics.arc("line", "open", cx - r * 0.15, cy - r * 0.15, r * 0.55, math.pi * 1.1, math.pi * 1.5)

    love.graphics.pop()
end

--- Draw all cargo slots
---@param bounds table Panel bounds
---@param slotRects table Array of slot rectangles
---@param hold table Cargo hold component
---@param hoverIdx number|nil Hovered slot index
---@param dragFrom number|nil Slot being dragged from
function M.drawSlots(bounds, slotRects, hold, hoverIdx, dragFrom)
    for i = 1, #slotRects do
        local r = slotRects[i]
        local slot = r and r.idx and hold.slots[r.idx] or nil
        if dragFrom and r and r.idx == dragFrom then
            slot = nil
        end

        if r then
            local isHover = hoverIdx == (r and r.idx)
            love.graphics.setColor(0, 0, 0, isHover and 0.55 or 0.35)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)

            love.graphics.setColor(1, 1, 1, isHover and 0.55 or 0.25)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h)

            if slot and slot.id and slot.volume and slot.volume > 0 then
                local def = Items.get(slot.id)
                local c = (def and def.color) or { 1, 1, 1, 0.9 }

                if def and def.icon then
                    ItemIcons.draw(slot.id, r.x + 3, r.y + 3, r.w - 6, r.h - 6, { tint = { 1, 1, 1, 0.95 } })
                else
                    love.graphics.setColor(c[1], c[2], c[3], 0.75)
                    love.graphics.rectangle("fill", r.x + 3, r.y + 3, r.w - 6, r.h - 6)
                end

                local countText = tostring(math.floor(slot.volume)) .. "m3"
                local font = love.graphics.getFont()
                local tw = font:getWidth(countText)
                local th = font:getHeight()

                love.graphics.setColor(0, 0, 0, 0.85)
                love.graphics.print(countText, r.x + r.w - tw - 4 + 1, r.y + r.h - th - 2 + 1)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print(countText, r.x + r.w - tw - 4, r.y + r.h - th - 2)
            end
        end
    end
end

--- Draw dragged item at cursor
---@param drag table Drag data with id and volume
---@param slotSize number Slot size for scaling
function M.drawDragItem(drag, slotSize)
    if not drag or not drag.id or not drag.volume or drag.volume <= 0 then
        return
    end

    local mx, my = love.mouse.getPosition()
    local def = Items.get(drag.id)
    local c = (def and def.color) or { 1, 1, 1, 0.9 }

    local dragSize = math.max(28, math.floor(slotSize * 0.6))
    local dragHalf = dragSize * 0.5

    if def and def.icon then
        ItemIcons.draw(drag.id, mx - dragHalf, my - dragHalf, dragSize, dragSize, { tint = { 1, 1, 1, 0.9 } })
    else
        love.graphics.setColor(c[1], c[2], c[3], 0.7)
        love.graphics.rectangle("fill", mx - dragHalf, my - dragHalf, dragSize, dragSize)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.rectangle("line", mx - dragHalf, my - dragHalf, dragSize, dragSize)
    end

    local countText = tostring(math.floor(drag.volume)) .. "m3"
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(countText, mx + 16 + 1, my - 10 + 1)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print(countText, mx + 16, my - 10)
end

--- Draw the footer capacity bar with credits display
---@param ctx table HUD context
---@param bounds table Panel bounds with footerRect
---@param used number Used capacity
---@param capacity number Total capacity
function M.drawFooterBar(ctx, bounds, used, capacity)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors

    local footer = bounds.footerRect
    local font = love.graphics.getFont()
    local th = font:getHeight()

    -- Get player credits
    local credits = 0
    if ctx and ctx.world then
        local player = ctx.world:getResource("player")
        if player and player:has("credits") then
            credits = player.credits.balance or 0
        end
    end

    -- Left side: Credits display
    local creditIconSize = 16
    local creditIconX = footer.x + 8 + creditIconSize / 2
    local creditIconY = footer.y + footer.h / 2

    drawCreditIcon(creditIconX, creditIconY, creditIconSize)

    local creditText = string.format("%d cr", credits)
    local creditTw = font:getWidth(creditText)
    love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], 0.75)
    love.graphics.print(creditText, creditIconX + creditIconSize / 2 + 5 + 1, creditIconY - th / 2 + 1)
    love.graphics.setColor(0.95, 0.85, 0.40, 0.95)
    love.graphics.print(creditText, creditIconX + creditIconSize / 2 + 5, creditIconY - th / 2)

    -- Right side: Capacity bar
    local barPadX = 10
    local creditsWidth = creditIconSize + creditTw + 20
    local barH = (hudTheme.cargoPanel and hudTheme.cargoPanel.barH) or 10
    local barX = footer.x + creditsWidth + barPadX
    local barW = footer.w - creditsWidth - barPadX * 2
    local barY = footer.y + math.floor((footer.h - barH) * 0.5)

    local frac = 0
    if capacity > 0 then
        frac = used / capacity
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    end

    love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4])
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    local cp = hudTheme.cargoPanel or {}
    local warnFrac = cp.warnFrac or 0.85
    local dangerFrac = cp.dangerFrac or 0.95

    local fill
    if frac < warnFrac then
        fill = colors.good
    elseif frac < dangerFrac then
        fill = colors.warn
    else
        fill = colors.danger
    end
    love.graphics.setColor(fill[1], fill[2], fill[3], fill[4])
    love.graphics.rectangle("fill", barX, barY, barW * frac, barH)

    love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
    love.graphics.rectangle("line", barX, barY, barW, barH)

    local percent = math.floor(frac * 100 + 0.5)
    local label = tostring(percent) .. "%"

    local tw = font:getWidth(label)
    local padX = 4
    local maxTw = barW - padX * 2
    local sx = 1
    if tw > 0 and maxTw > 0 and tw > maxTw then
        sx = maxTw / tw
    end

    local tx = barX + (barW - tw * sx) * 0.5
    local ty = barY + (barH - th) * 0.5

    love.graphics.push()
    love.graphics.translate(tx, ty)
    love.graphics.scale(sx, 1)
    love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
    love.graphics.print(label, 1, 1)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    love.graphics.print(label, 0, 0)
    love.graphics.pop()
end

return M
