local ECS = require('src.ecs')

local EventSystem = {
    name = "EventSystem",
    priority = 50,
}

-- Internal global events holder (singleton entity)
EventSystem._globalEntity = nil

local function ensure_global_entity()
    if EventSystem._globalEntity and ECS.getComponent(EventSystem._globalEntity, "GlobalEvents") then
        return EventSystem._globalEntity
    end
    local ge = ECS.createEntity()
    ECS.addComponent(ge, "GlobalEvents", { events = {} })
    EventSystem._globalEntity = ge
    return ge
end

-- Emit an event (internal helper)
function EventSystem.emit(eventType, payload, sourceId, targetId)
    local evEntity = ECS.createEntity()
    local ev = {
        type = eventType,
        payload = payload or {},
        source = sourceId,
        target = targetId,
        time = (love and love.timer and love.timer.getTime) and love.timer.getTime() or os.time(),
    }
    ECS.addComponent(evEntity, "Event", ev)
    return evEntity
end

function EventSystem.emitGlobal(eventType, payload, sourceId)
    return EventSystem.emit(eventType, payload, sourceId, nil)
end

function EventSystem.emitTo(eventType, targetEntityId, payload, sourceId)
    return EventSystem.emit(eventType, payload, sourceId, targetEntityId)
end

local function deliver_event_to_target(event)
    -- If an explicit numeric target is provided, deliver into its inbox
    if event.target and type(event.target) == "number" then
            local inbox = ECS.getComponent(event.target, "EventInbox")
            if not inbox then
                ECS.addComponent(event.target, "EventInbox", { events = {} })
                inbox = ECS.getComponent(event.target, "EventInbox")
            end
            table.insert(inbox.events, event)
            return true
        end

    -- Fallback: add to global events
    local ge = ensure_global_entity()
    local geComp = ECS.getComponent(ge, "GlobalEvents")
    table.insert(geComp.events, event)
    return true
end

function EventSystem.update(dt)
    -- Process transient Event entities and deliver them into inboxes/global list
    local evEntities = ECS.getEntitiesWith({ "Event" })
    for _, evEnt in ipairs(evEntities) do
        local ev = ECS.getComponent(evEnt, "Event")
        if ev then
            deliver_event_to_target(ev)
        end
        -- Destroy the temporary event entity so it's not processed again
        ECS.destroyEntity(evEnt)
    end
end

-- Helpers to read and clear global/inbox events
function EventSystem.fetchGlobalEvents()
    local ge = ensure_global_entity()
    local geComp = ECS.getComponent(ge, "GlobalEvents")
    return geComp and geComp.events or {}
end

function EventSystem.clearGlobalEvents()
    local ge = ensure_global_entity()
    local geComp = ECS.getComponent(ge, "GlobalEvents")
    if geComp then
        geComp.events = {}
    end
end

function EventSystem.clearInbox(entityId)
    local inbox = ECS.getComponent(entityId, "EventInbox")
    if inbox then
        inbox.events = {}
    end
end

return EventSystem


