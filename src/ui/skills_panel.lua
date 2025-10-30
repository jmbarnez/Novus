---@diagnostic disable: undefined-global
-- UI Skills Panel Module - Handles skills display (panel logic only, no window)

local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local SkillXP = require('src.systems.skill_xp')

local SkillsPanel = {}

-- Local UI state for expand/collapse per skill key
local expandedSkills = {}

-- Clickable rects for arrows/headers per draw pass
-- Filled each frame by draw(); consumed by mousepressed via wrapper
SkillsPanel._entryRects = {}

-- Static descriptors for what grants XP per skill (display only)
local XP_SOURCES = {
    mining = {
        title = "Gains XP From:",
        items = {
            { label = "Stone asteroid", xp = 6 },
            { label = "Iron asteroid", xp = 18 },
            -- Add more if needed, e.g., { label = "Crystal asteroid", xp = 30 }
        }
    },
    salvaging = {
        title = "Gains XP From:",
        items = {
            { label = "Small ships", xp = 8 },
        }
    },
    combat = {
        title = "Gains XP From:",
        items = {
            { label = "Destroying enemies", xp = nil },
        }
    }
}
-- Weapon skills
XP_SOURCES.lasers = {
    items = {
        { label = "Small drone", xp = 5 },
        { label = "Frigate", xp = 20 },
        { label = "Capital ship", xp = 40 },
    }
}
XP_SOURCES.missiles = {
    items = {
        { label = "Small drone", xp = 12 },
        { label = "Frigate", xp = 30 },
        { label = "Capital ship", xp = 60 },
    }
}
XP_SOURCES.kinetic = {
    items = {
        { label = "Small drone", xp = 7 },
        { label = "Frigate", xp = 22 },
        { label = "Capital ship", xp = 45 },
    }
}

-- Draw the skills panel content
function SkillsPanel.draw(shipWin, x, y, width, height, alpha)
    local contentX = x + 10
    local contentY = y + Theme.window.topBarHeight + 40 + 10  -- Align with tab area like Cargo panel
    local contentWidth = (shipWin and shipWin.width or width) - 20
    local contentHeight = (shipWin and shipWin.height or height) - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 40 - 20

    -- Get player skills
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then return end

    local playerId = playerEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills then return end

    local currentY = contentY
    SkillsPanel._entryRects = {}

    -- Iterate all skills present on the player in a consistent order
    local ordered = {}
    for key, data in pairs(skills.skills) do table.insert(ordered, {key = key, data = data}) end
    table.sort(ordered, function(a, b) return a.key < b.key end)

    for _, entry in ipairs(ordered) do
        local skillKey = entry.key
        local skillData = entry.data
        local displayName = skillKey:gsub("^%l", string.upper)
        local barColor = skillKey == "mining" and {0.2, 0.6, 1.0}
            or skillKey == "salvaging" and {0.2, 1.0, 0.2}
            or {1.0, 0.7, 0.2}

        local usedHeight = SkillsPanel.drawSkillEntry(shipWin, skillKey, displayName, skillData, contentX, currentY, contentWidth, alpha, barColor)
        currentY = currentY + usedHeight + 14
    end
end

-- Helper to draw a single skill entry
function SkillsPanel.drawSkillEntry(shipWin, skillKey, skillName, skill, x, y, width, alpha, barColor)
    local corner = Theme.window.cornerRadius or 0
    local headerH = 76
    local padding = 10
    local expanded = expandedSkills[skillKey] == true

    -- Background panel for the entry
    do
        local bg = Theme.colors.surface
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.9 * alpha)
        love.graphics.rectangle("fill", x, y, width, headerH, corner, corner)
        local border = Theme.colors.border
        love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * 0.6 * alpha)
        love.graphics.rectangle("line", x, y, width, headerH, corner, corner)
    end

    -- Arrow toggle (triangle) at left within header
    local arrowW, arrowH = 10, 8
    local arrowCx = x + padding + 8
    local arrowCy = y + headerH / 2
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
    if expanded then
        -- Up-pointing triangle
        love.graphics.polygon('fill',
            arrowCx - arrowW/2, arrowCy + arrowH/2,
            arrowCx + arrowW/2, arrowCy + arrowH/2,
            arrowCx,            arrowCy - arrowH/2)
    else
        -- Down-pointing triangle
        love.graphics.polygon('fill',
            arrowCx - arrowW/2, arrowCy - arrowH/2,
            arrowCx + arrowW/2, arrowCy - arrowH/2,
            arrowCx,            arrowCy + arrowH/2)
    end

    -- Skill name and level
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.print(skillName, x + padding + 24, y + 12)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.printf("Lvl " .. skill.level, x + padding, y + 14, width - padding * 2, "right")

    -- Progress details line
    local xpRatio = math.min(1, skill.experience / math.max(1, skill.requiredXp))
    local percent = math.floor(xpRatio * 100)
    local detail = string.format("%d/%d XP (%d%%)  •  Total: %d", skill.experience, skill.requiredXp, percent, skill.totalXp or 0)
    love.graphics.setColor(Theme.colors.textMuted and Theme.colors.textMuted[1] or Theme.colors.text[1], Theme.colors.textMuted and Theme.colors.textMuted[2] or Theme.colors.text[2], Theme.colors.textMuted and Theme.colors.textMuted[3] or Theme.colors.text[3], 0.9 * alpha)
    love.graphics.print(detail, x + padding + 24, y + 40)

    -- Experience bar under header (slim)
    local barX = x + padding + 24
    local barY = y + 58
    local barWidth = width - (padding + 24) - padding
    local barHeight = 8
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9 * alpha)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)
    love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2], Theme.colors.borderAlt[3], alpha)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 3, 3)
    local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
    love.graphics.setColor(barColor[1], barColor[2], barColor[3], alpha)
    love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2, 3, 3)

    -- Record clickable rects (header acts as toggle)
    SkillsPanel._entryRects[skillKey] = {
        x = x, y = y, w = width, h = headerH,
        arrow = { x = arrowCx - 10, y = arrowCy - 10, w = 20, h = 20 }
    }

    local usedHeight = headerH

    -- Expanded content block
    if expanded then
        local blockPadding = 12
        local blockX = x + 12
        local blockY = y + headerH + 8
        local blockW = width - 24

        -- Items for layout calc (no title line)
        local desc = XP_SOURCES[skillKey]
        local itemsCount = (desc and desc.items and #desc.items) or 0
        local contentH = blockPadding + (itemsCount * 18) + blockPadding

        -- Background for expanded area
        local bg2 = Theme.colors.surfaceAlt
        love.graphics.setColor(bg2[1], bg2[2], bg2[3], 0.85 * alpha)
        love.graphics.rectangle("fill", blockX, blockY, blockW, contentH, corner, corner)
        local border2 = Theme.colors.border
        love.graphics.setColor(border2[1], border2[2], border2[3], (border2[4] or 1) * 0.5 * alpha)
        love.graphics.rectangle("line", blockX, blockY, blockW, contentH, corner, corner)

        -- Items only (no title line)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)

        local lineY = blockY + blockPadding
        if desc and desc.items then
            for i = 1, #desc.items do
                local item = desc.items[i]
                local label = type(item) == 'table' and item.label or tostring(item)
                local xp = (type(item) == 'table' and item.xp) or nil
                love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
                love.graphics.circle('fill', blockX + blockPadding + 2, lineY + 6, 2)
                love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
                local lineText = xp and (string.format("%s: +%d XP", label, xp)) or label
                love.graphics.print(lineText, blockX + blockPadding + 10, lineY)
                lineY = lineY + 18
            end
        end

        usedHeight = usedHeight + 8 + contentH
    end

    return usedHeight
end

-- Toggle expand state if clicking within header/arrow
function SkillsPanel.mousepressed(shipWin, x, y, button)
    if button ~= 1 or not SkillsPanel._entryRects then return end
    for skillKey, r in pairs(SkillsPanel._entryRects) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            expandedSkills[skillKey] = not expandedSkills[skillKey]
            return true
        end
    end
    return false
end

return SkillsPanel

