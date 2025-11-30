local Concord = require "lib.concord.concord"
local Camera = require "lib.hump.camera"
local Config = require "src.config"
local Background = require "src.rendering.background"
local ShipSystem = require "src.ecs.spawners.ship"
local StationManager = require "src.ecs.spawners.station"
local SectorManager = require "src.managers.sector_manager"
local SaveManager = require "src.managers.save_manager"
local SoundManager = require "src.managers.sound_manager"
local FloatingTextSpawner = require "src.utils.floating_text_spawner"
local DefaultSector = require "src.data.default_sector"
local Client = require "src.network.client"

local PlayWorld = {}

local function createLocalPlayerInternal(world)
    local player = Concord.entity(world)
    player:give("wallet", 1000)
    player:give("skills")
    player:give("level")
    player:give("input")
    player:give("pilot")
    return player
end

function PlayWorld.createLocalPlayer(world)
    return createLocalPlayerInternal(world)
end

local function linkPlayerToShipInternal(player, ship)
    if not (player and ship and ship.input) then return end
    player:give("controlling", ship)
    player.input = ship.input
end

function PlayWorld.linkPlayerToShip(player, ship)
    linkPlayerToShipInternal(player, ship)
end

local function loadSnapshotInternal(loadParams)
    local snapshot
    if loadParams and loadParams.mode == "load" then
        local slot = loadParams.slot or 1
        local loaded, err = SaveManager.load(slot)
        if loaded then
            snapshot = loaded
        elseif err then
            print("PlayState: failed to load save slot " .. tostring(slot) .. ": " .. tostring(err))
        end
    end
    return snapshot
end

function PlayWorld.loadSnapshot(loadParams)
    return loadSnapshotInternal(loadParams)
end

local function getSpawnParamsFromSnapshotInternal(snapshot, default_ship_name)
    local spawn_x, spawn_y = 0, 0
    local ship_name = default_ship_name or "starter_drone"
    local sector_x, sector_y

    if snapshot and snapshot.player and snapshot.player.ship then
        local s = snapshot.player.ship
        if s.transform then
            spawn_x = s.transform.x or spawn_x
            spawn_y = s.transform.y or spawn_y
        end
        if s.sector then
            sector_x = s.sector.x
            sector_y = s.sector.y
        end
        ship_name = s.ship_name or ship_name
    end

    return spawn_x, spawn_y, ship_name, sector_x, sector_y
end

function PlayWorld.getSpawnParamsFromSnapshot(snapshot, default_ship_name)
    return getSpawnParamsFromSnapshotInternal(snapshot, default_ship_name)
end

function PlayWorld.showSaveFeedback(world, slot, ok)
    if not world then
        return
    end

    local ship = world.local_ship
    if ship and ship.transform then
        local x = ship.transform.x or 0
        local y = ship.transform.y or 0
        local text
        local color
        if ok then
            text = string.format("Game saved (slot %d)", slot or 1)
            color = { 0.3, 1.0, 0.6, 1.0 }
        else
            text = "Save failed"
            color = { 1.0, 0.3, 0.3, 1.0 }
        end
        FloatingTextSpawner.spawn(world, text, x, y, color)
    end

    SoundManager.play_sound("button_click")
end

function PlayWorld.initWorld(state)
    state.world = Concord.world()
    state.world.background = Background.new(Config.BACKGROUND.ENABLE_NEBULA ~= false)
    state.world.debug_asteroid_overlay = false
    state.world.player_dead = false
    state.world.player_death_time = nil

    state.world.camera = Camera.new()
    state.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    state.world.physics_world = love.physics.newWorld(0, 0, true)

    state.world.hosting = false
    state.server_time_offset = nil
    state.world.networked_entities = {}
    state.world.interpolation_buffers = {}
    state.player_entity_ids = {}
    state.player_display_names = {}
    state.my_entity_id = nil
end

function PlayWorld.spawnInitialEntities(state, is_joining, snapshot)
    local spawn_x, spawn_y, ship_name, sector_x, sector_y = getSpawnParamsFromSnapshotInternal(snapshot, "starter_drone")

    if not is_joining then
        local ship = ShipSystem.spawn(state.world, ship_name, spawn_x, spawn_y, true)
        if sector_x and ship.sector then
            ship.sector.x = sector_x
            ship.sector.y = sector_y
        end
        linkPlayerToShipInternal(state.player, ship)
        state.world.local_ship = ship

        local player_sector_x = (ship.sector and ship.sector.x) or 0
        local player_sector_y = (ship.sector and ship.sector.y) or 0
        local seed = Config.UNIVERSE_SEED or 12345

        StationManager.spawn(state.world, "starter_station", 500, 500)

        SectorManager.ensure_sector_loaded(state.world, player_sector_x, player_sector_y)
    else
        print("PlayState: Joining game, waiting for server spawn...")
    end

    if snapshot and not is_joining then
        SaveManager.apply_snapshot(state.world, state.player, state.world.local_ship, snapshot)
    end
end

function PlayWorld.updatePlayerCenters(state)
    if not state.world then return end

    local centers = {}

    local local_ship = state.world.local_ship
    if local_ship and local_ship.transform and local_ship.sector then
        centers[#centers + 1] = {
            x = local_ship.transform.x,
            y = local_ship.transform.y,
            sx = local_ship.sector.x or 0,
            sy = local_ship.sector.y or 0,
        }
    end

    if state.player_entity_ids and state.world.networked_entities then
        for _, entity_id in pairs(state.player_entity_ids) do
            local e = state.world.networked_entities[entity_id]
            if e and e.transform and e.sector then
                centers[#centers + 1] = {
                    x = e.transform.x,
                    y = e.transform.y,
                    sx = e.sector.x or 0,
                    sy = e.sector.y or 0,
                }
            end
        end
    end

    state.world.player_centers = centers
end

function PlayWorld.tryDockAtStation(state)
    local world = state.world
    if not (world and world.local_ship and world.ui and world.ui.hover_target) then
        return
    end

    local ship = world.local_ship
    local target = world.ui.hover_target

    if not (target.station and target.transform and target.sector and ship.transform and ship.sector) then
        return
    end

    local ship_sx = ship.sector.x or 0
    local ship_sy = ship.sector.y or 0
    local target_sx = target.sector.x or 0
    local target_sy = target.sector.y or 0

    local ex = target.transform.x + (target_sx - ship_sx) * DefaultSector.SECTOR_SIZE
    local ey = target.transform.y + (target_sy - ship_sy) * DefaultSector.SECTOR_SIZE

    local dx = ex - ship.transform.x
    local dy = ey - ship.transform.y
    local dist = math.sqrt(dx * dx + dy * dy)

    local dock_radius = (target.station_area and target.station_area.radius) or 0
    if dock_radius <= 0 or dist > dock_radius then
        return
    end

    if Client.connected and not world.hosting then
        Client.requestDock()
        return
    end

    if ship.hull and ship.hull.max then
        ship.hull.current = ship.hull.max
    end
    if ship.shield and ship.shield.max then
        ship.shield.current = ship.shield.max
    end
    if ship.energy and ship.energy.max then
        ship.energy.current = ship.energy.max
    end

    if ship.physics and ship.physics.body then
        ship.physics.body:setLinearVelocity(0, 0)
        ship.physics.body:setAngularVelocity(0)
    end

    local e = Concord.entity(world)
    local text = "Docked: ship resupplied"
    local color = { 0.3, 1.0, 0.6, 1.0 }
    e:give("floating_text", text, ex, ey, 1.6, color)
end

function PlayWorld.respawnLocalPlayer(state)
    if Client.connected and not state.world.hosting then
        Client.requestRespawn()
    else
        local ship = ShipSystem.spawn(state.world, "starter_drone", 0, 0, true)
        if ship then
            state.world.local_ship = ship
            linkPlayerToShipInternal(state.player, ship)
            state.world.player_dead = false
            state.world.player_death_time = nil

            if state.world.hosting then
                local Server = require "src.network.server"
                ship.network_id = Server.next_network_id
                Server.next_network_id = Server.next_network_id + 1
            end
        end
    end
end

return PlayWorld
