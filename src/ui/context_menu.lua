---@diagnostic disable: undefined-global
local Theme = require('src.ui.plasma_theme')

local ContextMenu = {}

local menu = nil

function ContextMenu.open(menuTable, onSelect)
    menu = {}
    menu.itemId = menuTable.itemId
    menu.itemDef = menuTable.itemDef
    menu.x = menuTable.x or 0
    menu.y = menuTable.y or 0
    menu.options = menuTable.options or {}
    menu.hoveredOption = nil
    menu.onSelect = onSelect

    local menuFont = Theme.getFont(Theme.fonts.normal)
    local fontHeight = menuFont:getHeight()
    local paddingX = 22
    local paddingY = 12
    local optionHeight = math.max(fontHeight + 10, 28)
    local minWidth = 280
    local maxTextWidth = 0
    for _, option in ipairs(menu.options) do
        local text = option.text or ""
        maxTextWidth = math.max(maxTextWidth, menuFont:getWidth(text))
    end

    menu.width = math.max(minWidth, maxTextWidth + paddingX * 2)
    menu.height = paddingY * 2 + optionHeight * #menu.options
    menu.paddingX = paddingX
    menu.paddingY = paddingY
    menu.optionHeight = optionHeight
    menu.fontSize = Theme.fonts.normal
    menu.fontLineHeight = fontHeight
    menu.highlightInset = 4
end

function ContextMenu.close()
    menu = nil
end

function ContextMenu.isOpen()
    return menu ~= nil
end

function ContextMenu.getMenu()
    return menu
end

function ContextMenu.draw(alpha)
    if not menu then return end
    local x = menu.x
    local y = menu.y

    local bgColor = Theme.colors.surfaceAlt
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha * 0.94)
    love.graphics.rectangle("fill", x, y, menu.width, menu.height)

    local accent = Theme.colors.hover
    love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * alpha * 0.35)
    love.graphics.rectangle("fill", x, y, menu.width, 2)

    local borderColor = Theme.colors.border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, menu.width, menu.height)

    local font = Theme.getFont(menu.fontSize or Theme.fonts.normal)
    love.graphics.setFont(font)
    local fontHeight = menu.fontLineHeight or font:getHeight()

    for i, option in ipairs(menu.options) do
        local optionTop = y + menu.paddingY + (i - 1) * menu.optionHeight
        local isHovered = menu.hoveredOption == i

        if isHovered then
            love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * alpha * 0.18)
            love.graphics.rectangle("fill", x + menu.highlightInset, optionTop, menu.width - menu.highlightInset * 2, menu.optionHeight)
        end

        local textColor = Theme.colors.text
        if option.action == "equip" and option.slotType then
            if option.slotType == "Turret Module" then
                textColor = Theme.colors.accent
            elseif option.slotType == "Defensive Module" then
                textColor = Theme.colors.textSecondary
            elseif option.slotType == "Generator Module" then
                textColor = Theme.colors.text
            end
        elseif option.action == "noop" then
            textColor = {
                Theme.colors.textSecondary[1] * 0.6,
                Theme.colors.textSecondary[2] * 0.6,
                Theme.colors.textSecondary[3] * 0.6,
                Theme.colors.textSecondary[4] or 1
            }
        end

        love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * alpha)

        local textY = optionTop + (menu.optionHeight - fontHeight) / 2
        love.graphics.print(option.text or "", x + menu.paddingX, textY)
    end
end

function ContextMenu.hitTest(uiX, uiY)
    if not menu then return false end
    return uiX >= menu.x and uiX <= menu.x + menu.width and uiY >= menu.y and uiY <= menu.y + menu.height
end

function ContextMenu.handleClickAt(uiX, uiY)
    if not menu then return false end
    if not ContextMenu.hitTest(uiX, uiY) then return false end

    local relativeY = uiY - (menu.y + (menu.paddingY or 12))
    if relativeY < 0 then
        ContextMenu.close()
        return false
    end

    local optionIndex = math.floor(relativeY / (menu.optionHeight or 28)) + 1
    if optionIndex >= 1 and optionIndex <= #menu.options then
        local option = menu.options[optionIndex]
        if menu.onSelect then menu.onSelect(option) end
        ContextMenu.close()
        return true
    end

    ContextMenu.close()
    return false
end

function ContextMenu.mousemoved(uiX, uiY)
    if not menu then return end
    if ContextMenu.hitTest(uiX, uiY) then
        local relativeY = uiY - (menu.y + (menu.paddingY or 12))
        local optionIndex = relativeY >= 0 and (math.floor(relativeY / (menu.optionHeight or 28)) + 1) or nil
        if optionIndex and optionIndex >= 1 and optionIndex <= #menu.options then
            menu.hoveredOption = optionIndex
        else
            menu.hoveredOption = nil
        end
    else
        menu.hoveredOption = nil
    end
end

return ContextMenu


