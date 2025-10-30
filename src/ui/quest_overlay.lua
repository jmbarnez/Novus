---@diagnostic disable: undefined-global
-- Quest Overlay - Minimal quest tracker positioned near the minimap
-- Uses QuestSystem for data and HUD minimap layout for positioning

local Theme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')
local QuestSystem = require('src.systems.quest_system')
local HUDMinimap = require('src.systems.hud.minimap')

local QuestOverlay = {
    isOpen = true
}

local QUEST_PADDING = Theme.spacing.sm
local FRAME_PADDING = QUEST_PADDING * 1.5
local PANEL_SIDE_PADDING = QUEST_PADDING * 1.5
local ROW_HEIGHT = QUEST_PADDING * 8
local DIVIDER_HEIGHT = QUEST_PADDING * 0.75
local EXTRA_SPACING = QUEST_PADDING * 6

local cachedQuests = {}
local cachedVersion = -1

local function adoptQuestList(source)
    cachedQuests = {}
    for i = 1, #source do
        cachedQuests[i] = source[i]
    end
end

function QuestOverlay.invalidateCache()
    cachedVersion = -1
end

local function getQuests()
    local version = QuestSystem.getQuestStateVersion()
    if version ~= cachedVersion then
        adoptQuestList(QuestSystem.getActiveQuests())
        cachedVersion = QuestSystem.getQuestStateVersion()
    end
    return cachedQuests
end

local function calculateFrame(questCount)
    local minimapX, minimapY, minimapRadius = HUDMinimap.getLayout()

    local overlayWidth = (minimapRadius * 2) + PANEL_SIDE_PADDING * 2
    local overlayX = minimapX - minimapRadius - PANEL_SIDE_PADDING
    local overlayY = minimapY + minimapRadius + EXTRA_SPACING

    local listHeight = 0
    if questCount > 0 then
        listHeight = questCount * ROW_HEIGHT + math.max(0, questCount - 1) * DIVIDER_HEIGHT
    end

    local overlayHeight = listHeight + FRAME_PADDING * 2
    return overlayX, overlayY, overlayWidth, overlayHeight
end

local function computeProgress(quest)
    local req = quest.requirements
    if not req or not req.count or req.count <= 0 then
        return nil, nil
    end

    local current = math.max(0, math.min(req.count, req.current or 0))
    local fraction = req.count > 0 and (current / req.count) or 0
    local label = req.label or string.format("%d/%d", current, req.count)

    return math.min(fraction, 1), label
end

local function drawQuest(quest, x, y, w, h, fonts, alpha)
    local titleColor = quest.isMainStory and Theme.colors.success or Theme.colors.accent
    local currentY = y

    BatchRenderer.queueText(
        quest.title or "Quest",
        x,
        currentY,
        fonts.title,
        titleColor[1], titleColor[2], titleColor[3],
        alpha
    )
    currentY = currentY + fonts.title:getHeight() + QUEST_PADDING * 0.4

    local fraction, progressLabel = computeProgress(quest)
    local barHeight = QUEST_PADDING * 1.5
    local barY = y + h - barHeight - QUEST_PADDING * 0.5

    if fraction then
        local fillColor = quest.isMainStory and Theme.colors.success or Theme.colors.accent
        local border = Theme.colors.border

        if fraction > 0 then
            BatchRenderer.queueRect(
                x,
                barY,
                w * fraction,
                barHeight,
                fillColor[1], fillColor[2], fillColor[3],
                alpha,
                1
            )
        end

        BatchRenderer.queueRectLine(
            x,
            barY,
            w,
            barHeight,
            border[1], border[2], border[3],
            alpha,
            1,
            1
        )

        local labelWidth = fonts.small:getWidth(progressLabel)
        local labelHeight = fonts.small:getHeight()
        local textX = x + (w - labelWidth) / 2
        local textY = barY + (barHeight - labelHeight) / 2
        BatchRenderer.queueText(
            progressLabel,
            textX,
            textY,
            fonts.small,
            Theme.colors.text[1],
            Theme.colors.text[2],
            Theme.colors.text[3],
            alpha
        )
    end
end

function QuestOverlay.draw()
    if not QuestOverlay.isOpen then
        return
    end

    local quests = getQuests()
    if not quests or #quests == 0 then
        return
    end

    local overlayX, overlayY, overlayWidth, overlayHeight = calculateFrame(#quests)
    local alpha = 0.9
    local borderColor = Theme.colors.border

    local fonts = {
        title = Theme.getFont(Theme.fonts.normal),
        small = Theme.getFont(Theme.fonts.small),
        tiny = Theme.getFont(Theme.fonts.tiny)
    }

    local contentWidth = overlayWidth - PANEL_SIDE_PADDING * 2
    local rowY = overlayY + FRAME_PADDING

    for index, quest in ipairs(quests) do
        drawQuest(
            quest,
            overlayX + PANEL_SIDE_PADDING,
            rowY,
            contentWidth,
            ROW_HEIGHT,
            fonts,
            alpha
        )

        if index < #quests then
            local dividerY = rowY + ROW_HEIGHT
            BatchRenderer.queueRect(
                overlayX + PANEL_SIDE_PADDING,
                dividerY,
                contentWidth,
                DIVIDER_HEIGHT,
                borderColor[1], borderColor[2], borderColor[3],
                alpha * 0.45,
                1
            )
        end

        rowY = rowY + ROW_HEIGHT + DIVIDER_HEIGHT
    end
end

return QuestOverlay
