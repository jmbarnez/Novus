--- Refinery Queue Management
--- Handles starting, updating, and collecting smelting jobs

local Items = require("game.items")
local Inventory = require("game.inventory")

local RefineryQueue = {}

--- Start a new smelting job
--- @param station Entity with refinery_queue component
--- @param recipe Recipe table from Refinery.getRecipes()
--- @param quantity Number of output ingots to produce
--- @param oreVolume Volume of ore consumed (already removed from cargo)
--- @param fee Credits paid (already deducted)
--- @return boolean success, string message
function RefineryQueue.startJob(station, recipe, quantity, oreVolume, fee)
    if not station or not station.refinery_queue then
        return false, "Invalid station"
    end

    local queue = station.refinery_queue
    if #queue.jobs >= queue.maxSlots then
        return false, "Queue is full"
    end

    -- Calculate total processing time with batch bonuses
    local baseTime = recipe.timePerUnit or 3.0
    local totalTime = quantity * baseTime

    -- Apply batch bonuses (time reduction for larger batches)
    if recipe.batchBonuses then
        for _, bonus in ipairs(recipe.batchBonuses) do
            if quantity >= bonus.minQty and bonus.timeMultiplier then
                totalTime = totalTime * bonus.timeMultiplier
            end
        end
    end

    local job = {
        recipeInputId = recipe.inputId,
        recipeOutputId = recipe.outputId,
        quantity = quantity,
        progress = 0,
        totalTime = totalTime,
        oreConsumed = oreVolume,
        feePaid = fee,
        outputName = recipe.outputName or recipe.outputId,
    }

    table.insert(queue.jobs, job)
    return true, "Smelting started"
end

--- Update all jobs on a station (call every frame)
--- @param station Entity with refinery_queue component
--- @param dt Delta time in seconds
function RefineryQueue.update(station, dt)
    if not station or not station.refinery_queue then
        return
    end

    local queue = station.refinery_queue
    for _, job in ipairs(queue.jobs) do
        if job.progress < job.totalTime then
            job.progress = math.min(job.progress + dt, job.totalTime)
        end
    end
end

--- Check if a job is complete
--- @param job Job table
--- @return boolean
function RefineryQueue.isJobComplete(job)
    return job and job.progress >= job.totalTime
end

--- Get progress percentage for a job
--- @param job Job table
--- @return number 0-1
function RefineryQueue.getJobProgress(job)
    if not job or job.totalTime <= 0 then
        return 0
    end
    return math.min(1, job.progress / job.totalTime)
end

--- Get time remaining for a job
--- @param job Job table
--- @return number seconds remaining
function RefineryQueue.getTimeRemaining(job)
    if not job then
        return 0
    end
    return math.max(0, job.totalTime - job.progress)
end

--- Collect a completed job
--- @param station Entity with refinery_queue component
--- @param jobIndex Index of job in queue
--- @param ship Entity with cargo_hold component
--- @return boolean success, string message
function RefineryQueue.collectJob(station, jobIndex, ship)
    if not station or not station.refinery_queue then
        return false, "Invalid station"
    end

    local queue = station.refinery_queue
    local job = queue.jobs[jobIndex]

    if not job then
        return false, "Invalid job"
    end

    if not RefineryQueue.isJobComplete(job) then
        return false, "Job not complete"
    end

    if not ship or not ship.cargo_hold or not ship.cargo then
        return false, "No cargo hold"
    end

    -- Calculate output volume
    local outputDef = Items.get(job.recipeOutputId)
    local outputUnitVolume = (outputDef and outputDef.unitVolume) or 1
    local outputVolume = job.quantity * outputUnitVolume

    -- Check cargo space
    local freeSpace = ship.cargo.capacity - ship.cargo.used
    if outputVolume > freeSpace then
        return false, "Not enough cargo space"
    end

    -- Add ingots to cargo
    local remaining = Inventory.addToSlots(ship.cargo_hold.slots, job.recipeOutputId, outputVolume)
    if remaining > 0 then
        return false, "Could not add ingots to cargo"
    end

    -- Update cargo used
    ship.cargo.used = Inventory.totalVolume(ship.cargo_hold.slots)

    -- Remove job from queue
    table.remove(queue.jobs, jobIndex)

    return true, "Collected " .. job.quantity .. " " .. job.outputName
end

--- Get all jobs for a station
--- @param station Entity with refinery_queue component
--- @return table Array of jobs
function RefineryQueue.getJobs(station)
    if not station or not station.refinery_queue then
        return {}
    end
    return station.refinery_queue.jobs
end

--- Get number of free slots
--- @param station Entity with refinery_queue component
--- @return number
function RefineryQueue.getFreeSlots(station)
    if not station or not station.refinery_queue then
        return 0
    end
    local queue = station.refinery_queue
    return queue.maxSlots - #queue.jobs
end

return RefineryQueue
