---@diagnostic disable: undefined-global
-- Simple profiler to identify performance bottlenecks
local Profiler = {}

Profiler.enabled = false
Profiler.timers = {}
Profiler.results = {}
Profiler.frameCount = 0
Profiler.cullStats = {
    itemsRendered = 0,
    itemsCulled = 0
}

function Profiler.enable()
    Profiler.enabled = true
end

function Profiler.disable()
    Profiler.enabled = false
end

function Profiler.start(name)
    if not Profiler.enabled then return end
    Profiler.timers[name] = love.timer.getTime()
end

function Profiler.stop(name)
    if not Profiler.enabled then return end
    
    local startTime = Profiler.timers[name]
    if not startTime then return end
    
    local elapsed = (love.timer.getTime() - startTime) * 1000 -- Convert to ms
    
    if not Profiler.results[name] then
        Profiler.results[name] = {
            total = 0,
            count = 0,
            min = math.huge,
            max = 0
        }
    end
    
    local result = Profiler.results[name]
    result.total = result.total + elapsed
    result.count = result.count + 1
    result.min = math.min(result.min, elapsed)
    result.max = math.max(result.max, elapsed)
    
    Profiler.timers[name] = nil
end

function Profiler.reset()
    Profiler.results = {}
    Profiler.frameCount = 0
end

function Profiler.print()
    if not Profiler.enabled then return end
    
    print("\n=== PROFILER RESULTS ===")
    print(string.format("Frames: %d", Profiler.frameCount))
    print(string.format("%-30s %8s %8s %8s %8s", "Name", "Avg (ms)", "Min (ms)", "Max (ms)", "Calls"))
    print(string.rep("-", 70))
    
    -- Sort by average time
    local sorted = {}
    for name, data in pairs(Profiler.results) do
        table.insert(sorted, {name = name, data = data})
    end
    table.sort(sorted, function(a, b)
        return (a.data.total / a.data.count) > (b.data.total / b.data.count)
    end)
    
    for _, entry in ipairs(sorted) do
        local name = entry.name
        local data = entry.data
        local avg = data.total / data.count
        print(string.format("%-30s %8.3f %8.3f %8.3f %8d", 
            name, avg, data.min, data.max, data.count))
    end
    
    print(string.rep("-", 70))
    
    -- Print culling statistics
    local totalItems = Profiler.cullStats.itemsRendered + Profiler.cullStats.itemsCulled
    if totalItems > 0 then
        local cullEfficiency = (Profiler.cullStats.itemsCulled / totalItems) * 100
        print(string.format("\n=== CULLING STATISTICS ==="))
        print(string.format("Items rendered: %d", Profiler.cullStats.itemsRendered))
        print(string.format("Items culled: %d", Profiler.cullStats.itemsCulled))
        print(string.format("Culling efficiency: %.1f%%", cullEfficiency))
        print(string.rep("-", 70))
    end
end

function Profiler.frame()
    if not Profiler.enabled then return end
    Profiler.frameCount = Profiler.frameCount + 1
end

function Profiler.recordCulling(rendered, culled)
    Profiler.cullStats.itemsRendered = Profiler.cullStats.itemsRendered + rendered
    Profiler.cullStats.itemsCulled = Profiler.cullStats.itemsCulled + culled
end

return Profiler

