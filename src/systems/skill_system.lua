local ECS = require('src.ecs')
local EventSystem = require('src.systems.event_system')
local SkillUtils = require('src.skill_utils')

local SkillSystem = {
    name = "SkillSystem",
    priority = 60,
}

-- Process SkillGain events from global list and per-entity inboxes
function SkillSystem.update(dt)
    -- Global events
    local globalEvents = EventSystem.fetchGlobalEvents()
    for _, ev in ipairs(globalEvents) do
        if ev.type == "SkillGain" then
            local payload = ev.payload or {}
            local skillName = payload.skill
            local xp = payload.xp or 0
            -- Try to apply to explicit target if present, otherwise to first player
            local targetId = ev.target
            SkillUtils.addSkillExperience(skillName, xp, targetId)
        end
    end
    EventSystem.clearGlobalEvents()

    -- Per-entity inboxes
    local inboxEntities = ECS.getEntitiesWith({"EventInbox"})
    for _, ent in ipairs(inboxEntities) do
        local inbox = ECS.getComponent(ent, "EventInbox")
        if inbox and inbox.events and #inbox.events > 0 then
            for _, ev in ipairs(inbox.events) do
                if ev.type == "SkillGain" then
                    local payload = ev.payload or {}
                    local skillName = payload.skill
                    local xp = payload.xp or 0
                    -- Deliver to this entity (ent) since it's in their inbox
                    SkillUtils.addSkillExperience(skillName, xp, ent)
                end
            end
            -- Clear processed events
            inbox.events = {}
        end
    end
end

return SkillSystem


