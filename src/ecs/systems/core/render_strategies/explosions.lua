local Common = require "src.ecs.systems.core.render_strategies.common"

local Explosions = {}

local explosionShader = nil
local explosionMesh = nil

local function ensureExplosionShader()
    if explosionShader then
        return explosionShader
    end

    local shader_path = "assets/shaders/ship_explosion.glsl"
    if love.filesystem.getInfo(shader_path) then
        explosionShader = love.graphics.newShader(shader_path)
    end

    return explosionShader
end

local function ensureExplosionMesh()
    if explosionMesh then
        return explosionMesh
    end

    local segments = 32
    local vertices = {}

    local center_u, center_v = 0.5, 0.5

    for i = 0, segments - 1 do
        local angle1 = (i / segments) * math.pi * 2
        local angle2 = ((i + 1) / segments) * math.pi * 2

        table.insert(vertices, { 0, 0, center_u, center_v, 1, 1, 1, 1 })

        local x1 = math.cos(angle1)
        local y1 = math.sin(angle1)
        local u1 = (x1 + 1) * 0.5
        local v1 = (y1 + 1) * 0.5
        table.insert(vertices, { x1, y1, u1, v1, 1, 1, 1, 1 })

        local x2 = math.cos(angle2)
        local y2 = math.sin(angle2)
        local u2 = (x2 + 1) * 0.5
        local v2 = (y2 + 1) * 0.5
        table.insert(vertices, { x2, y2, u2, v2, 1, 1, 1, 1 })
    end

    explosionMesh = love.graphics.newMesh(vertices, "triangles", "static")
    return explosionMesh
end

function Explosions.ship_explosion(e)
    local r = e.render
    if not r then
        return
    end

    local cr, cg, cb, ca = Common.getColorFromRender(r)
    local radius = Common.getRadiusFromRender(r, 20)

    local shader = ensureExplosionShader()
    local mesh = ensureExplosionMesh()

    if shader and mesh then
        local lifetime = e.lifetime
        local progress = 0

        if lifetime and lifetime.duration and lifetime.duration > 0 then
            local elapsed = lifetime.elapsed or 0
            progress = math.max(0, math.min(1, elapsed / lifetime.duration))
        end

        shader:send("time", love.timer.getTime())
        shader:send("progress", progress)
        shader:send("base_color", { cr, cg, cb })

        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.push()
        love.graphics.scale(radius, radius)
        love.graphics.draw(mesh)
        love.graphics.pop()

        love.graphics.setShader()
    else
        local lifetime = e.lifetime
        local alpha = ca

        if lifetime and lifetime.duration and lifetime.duration > 0 then
            local elapsed = lifetime.elapsed or 0
            local progress = math.max(0, math.min(1, elapsed / lifetime.duration))
            alpha = alpha * (1.0 - progress)
        end

        love.graphics.setColor(cr, cg, cb, alpha)
        love.graphics.circle("fill", 0, 0, radius)
    end
end

return Explosions
