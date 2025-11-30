local Gamestate           = require "lib.hump.gamestate"
local baton               = require "lib.baton"
local Camera              = require "lib.hump.camera"
local Concord             = require "lib.concord.concord"
local Config              = require "src.config"
local Background          = require "src.rendering.background"
local HUD                 = require "src.ui.hud.hud"
local Chat                = require "src.ui.hud.chat"
local PauseMenu           = require "src.ui.pause_menu"
local Theme               = require "src.ui.theme"
local SaveManager         = require "src.managers.save_manager"
local Window              = require "src.ui.hud.window"
local CargoPanel          = require "src.ui.hud.cargo_panel"
local MapPanel            = require "src.ui.hud.map_panel"
local Client              = require "src.network.client"
local Protocol            = require "src.network.protocol"
local PlayNetwork         = require "src.states.play_network"
local SectorManager       = require "src.managers.sector_manager"
local SoundManager        = require "src.managers.sound_manager"
local FloatingTextSpawner = require "src.utils.floating_text_spawner"
local PlayWorld           = require "src.states.play.world"
local PlayUI              = require "src.states.play.ui"

require "src.ecs.components"

--
-- System Imports
--

local PlayerControlSystem   = require "src.ecs.systems.gameplay.player_control"
local MovementSystem        = require "src.ecs.systems.core.movement"
local DeathSystem           = require "src.ecs.systems.gameplay.death"
local LootSystem            = require "src.ecs.systems.gameplay.loot"
local ShipDeathSystem       = require "src.ecs.systems.gameplay.ship_death"
local CollisionSystem       = require "src.ecs.systems.core.collision"
local MinimapSystem         = require "src.ecs.systems.visual.minimap"
local PhysicsSystem         = require "src.ecs.systems.core.physics"
local RenderSystem          = require "src.ecs.systems.core.render"
local ShipSystem            = require "src.ecs.spawners.ship"
local Asteroids             = require "src.ecs.spawners.asteroid"
local EnemySpawner          = require "src.ecs.spawners.enemy"
local WeaponSystem          = require "src.ecs.systems.gameplay.weapon"
local ProjectileSystem      = require "src.ecs.systems.gameplay.projectile"
local AsteroidChunkSystem   = require "src.ecs.systems.gameplay.asteroid_chunk"
local ProjectileShardSystem = require "src.ecs.systems.visual.projectile_shard"
local ExplosionSystem       = require "src.ecs.systems.visual.explosion"
local ItemPickupSystem      = require "src.ecs.systems.gameplay.item_pickup"
local TrailSystem           = require "src.ecs.systems.visual.trail"
local AISystem              = require "src.ecs.systems.gameplay.ai_system"
local DefaultSector         = require "src.data.default_sector"
local StationManager        = require "src.ecs.spawners.station"
local FloatingTextSystem    = require "src.ecs.systems.visual.floating_text"

--
-- LOCAL HELPER FUNCTIONS
--

--
-- PLAYSTATE DEFINITION
--

local PlayState = {}
PlayState.server_time_offset = nil

--
-- LIFECYCLE METHODS
--

function PlayState:enter(prev, param)
    local loadParams = (type(param) == "table") and param or nil
    local snapshot = PlayWorld.loadSnapshot(loadParams)
    local is_joining = loadParams and loadParams.mode == "join"
    local join_host = loadParams and loadParams.host or "localhost"

    self.isPaused = false

    self:initWorld()

    self:initUI()
    self:initNetwork(is_joining, join_host)
    self:initSystems()
    self:spawnInitialEntities(is_joining, snapshot)

    SoundManager.play_music("adrift", { loop = true })
end

function PlayState:update(dt)
    -- 1. Network & Chat Updates
    Chat.update(dt)
    self:updateNetwork(dt)

    -- 2. Input Management
    self:updateControls()

    if self.isPaused then
        if PauseMenu.update then
            PauseMenu.update(dt)
        end
        return
    end

    if self.world and self.world.local_ship and self.world.local_ship.transform then
        SoundManager.set_listener_position(self.world.local_ship.transform.x, self.world.local_ship.transform.y)
    end

    -- 3. World & Physics Updates
    if self.world.background then
        self.world.background:update(dt)
    end
    
    self:updatePlayerCenters()
    SectorManager.update_streaming(self.world, dt)
    self.world:emit("update", dt)

    -- 4. Network Interpolation (Client Only)
    if not self.world.hosting then
        self:updateInterpolation(dt)
        self:sendClientInput()
    end

    -- 5. UI Updates
    self:updateHover(dt)
    CargoPanel.update(dt, self.world)
    if MapPanel.update then
        MapPanel.update(dt, self.world)
    end
end

function PlayState:draw()
    local bg = Theme.getBackgroundColor()
    love.graphics.setBackgroundColor(bg[1], bg[2], bg[3], bg[4] or 1)
    
    self.world:emit("draw")

    love.graphics.origin()
    HUD.draw(self.world, self.player)
    Chat.draw()
 
    if self.isPaused then
        PauseMenu.draw()
    end

    self:drawDeathOverlay()
end

function PlayState:drawDeathOverlay()
    if self.world and self.world.player_dead then
        local sw, sh = love.graphics.getDimensions()
        local dim = Theme.colors.overlay.screenDim
        love.graphics.setColor(dim[1], dim[2], dim[3], dim[4] or 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        local textColor = Theme.colors.textPrimary
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        local font = love.graphics.getFont()
        local line_h = font:getHeight()
        local center_y = sh * 0.4

        love.graphics.printf("SHIP DESTROYED", 0, center_y, sw, "center")
        love.graphics.printf("Press R to respawn or ESC to return to menu", 0, center_y + line_h + 10, sw, "center")
    end
end

--
-- INPUT HANDLING
--

function PlayState:keypressed(key)
    if Chat.keypressed(key) then return end

    if self.world and self.world.player_dead then
        if key == "escape" then
            Gamestate.switch(require("src.states.menu"))
        elseif key == "r" or key == "return" or key == "space" then
            self:respawnLocalPlayer()
        end
        return
    end

    if self.isPaused then
        if key == "escape" then
            self.isPaused = false
            if PauseMenu.reset then
                PauseMenu.reset()
            end
        end
        return
    end

    if key == "escape" then
        if self.world and self.world.ui then
            local ui = self.world.ui
            local closedPanel = false

            if ui.map_open then
                ui.map_open = false
                closedPanel = true
            end

            if ui.cargo_open then
                ui.cargo_open = false
                if ui.cargo_drag then
                    ui.cargo_drag.active = false
                end
                closedPanel = true
            end

            if closedPanel then
                return
            end
        end

        self.isPaused = true
        return
    end

    if key == "f1" and self.world then
        self.world.debug_asteroid_overlay = not self.world.debug_asteroid_overlay
        return
    end

    if key == "f5" and not self.world.hosting then
        self:startHosting()
        return
    end

    if key == "f" and self.world then
        self:tryDockAtStation()
        return
    end

    if key == "m" and self.world and self.world.ui then
        self.world.ui.map_open = not self.world.ui.map_open
        return
    end

    if key == "tab" and self.world and self.world.ui then
        self.world.ui.cargo_open = not self.world.ui.cargo_open
        if not self.world.ui.cargo_open and self.world.ui.cargo_drag then
            self.world.ui.cargo_drag.active = false
        end
    elseif key == "f6" then
        local ok = SaveManager.save(1, self.world, self.player)
        PlayWorld.showSaveFeedback(self.world, 1, ok)
    elseif key == "f9" then
        if SaveManager.has_save(1) then
            Gamestate.switch(PlayState, { mode = "load", slot = 1 })
        end
    end
end

function PlayState:textinput(t)
    if Chat.textinput(t) then return end
end

function PlayState:mousepressed(x, y, button)
    if self.isPaused then
        local action = PauseMenu.mousepressed(x, y, button)

        if action == "resume" then
            self.isPaused = false
        elseif action == "menu" then
            Gamestate.switch(require("src.states.menu"))
        elseif action == "save_slot_1" then
            local ok = SaveManager.save(1, self.world, self.player)
            PlayWorld.showSaveFeedback(self.world, 1, ok)
        elseif action == "save_slot_2" then
            local ok = SaveManager.save(2, self.world, self.player)
            PlayWorld.showSaveFeedback(self.world, 2, ok)
        elseif action == "save_slot_3" then
            local ok = SaveManager.save(3, self.world, self.player)
            PlayWorld.showSaveFeedback(self.world, 3, ok)
        end
        return
    end

    if self.world and self.world.ui and self.world.ui.map_open then
        if button == 2 then
            self.world.ui.map_open = false
            return
        end

        if button == 1 then
            if MapPanel and MapPanel.mousepressed and MapPanel.mousepressed(x, y, button, self.world) then
                return
            end
            return
        end

        return
    end

    if button == 1 then
        if Chat.mousepressed and Chat.mousepressed(x, y, button) then
            return
        end
        CargoPanel.mousepressed(x, y, button, self.world)
    end
end

function PlayState:mousereleased(x, y, button)
    if self.isPaused then
        return
    end

    if button == 1 then
        if MapPanel and MapPanel.mousereleased then
            MapPanel.mousereleased(x, y, button, self.world)
        end
        CargoPanel.mousereleased(x, y, button, self.world)
    end
end

function PlayState:wheelmoved(x, y)
    if not self.world or not self.world.camera then return end
    local current_zoom = self.world.camera.scale
    local new_zoom = current_zoom + (y > 0 and Config.CAMERA_ZOOM_STEP or (y < 0 and -Config.CAMERA_ZOOM_STEP or 0))
    new_zoom = math.max(Config.CAMERA_MIN_ZOOM, math.min(new_zoom, Config.CAMERA_MAX_ZOOM))
    self.world.camera:zoomTo(new_zoom)
end

--
-- INITIALIZATION SUB-FUNCTIONS
--

function PlayState:initWorld()
    PlayWorld.initWorld(self)
end

function PlayState:initUI()
    PlayUI.initUI(self)
end

function PlayState:initNetwork(is_joining, join_host)
    PlayNetwork.initNetwork(self, is_joining, join_host)
end

function PlayState:initSystems()
    self.world.controls = baton.new({
        controls = {
            move_left  = { "key:a", "key:left" },
            move_right = { "key:d", "key:right" },
            move_up    = { "key:w", "key:up" },
            move_down  = { "key:s", "key:down" },
            fire       = { "mouse:1" },
            boost      = { "key:space" }
        }
    })
    self.world.controlsEnabled = true

    self.world:addSystems(
        PlayerControlSystem, AISystem, MovementSystem, PhysicsSystem, CollisionSystem,
        WeaponSystem, ProjectileSystem, DeathSystem, ShipDeathSystem, LootSystem,
        AsteroidChunkSystem, ProjectileShardSystem, ExplosionSystem, ItemPickupSystem, TrailSystem,
        RenderSystem, MinimapSystem, FloatingTextSystem
    )

    self.player = PlayWorld.createLocalPlayer(self.world)
end

function PlayState:spawnInitialEntities(is_joining, snapshot)
    PlayWorld.spawnInitialEntities(self, is_joining, snapshot)
end

--
-- UPDATE LOOPS
--

function PlayState:updateNetwork(dt)
    PlayNetwork.updateNetwork(self, dt)
end

function PlayState:updateControls()
    if self.isPaused then
        if self.world then
            self.world.controlsEnabled = false
        end
        return
    end

    if Chat.isActive() or (self.world and self.world.player_dead) then
        self.world.controlsEnabled = false
    else
        self.world.controlsEnabled = true
    end
end

function PlayState:updateInterpolation(dt)
    PlayNetwork.updateInterpolation(self, dt)
end

function PlayState:sendClientInput()
    PlayNetwork.sendClientInput(self)
end

function PlayState:updatePlayerCenters()
    PlayWorld.updatePlayerCenters(self)
end

function PlayState:updateHover(dt)
    PlayUI.updateHover(self, dt)
end

function PlayState:tryDockAtStation()
    PlayWorld.tryDockAtStation(self)
end

function PlayState:respawnLocalPlayer()
    PlayWorld.respawnLocalPlayer(self)
end

function PlayState:startHosting()
    PlayNetwork.startHosting(self)
end

return PlayState