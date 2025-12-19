local Items = require("game.items")

local Inventory = {}

local function isEmpty(slot)
  return not slot or not slot.id or (slot.volume or 0) <= 0
end

function Inventory.isEmpty(slot)
  return isEmpty(slot)
end

function Inventory.clear(slot)
  slot.id = nil
  slot.volume = 0
end

function Inventory.clone(slot)
  if isEmpty(slot) then
    return { id = nil, volume = 0 }
  end
  return { id = slot.id, volume = slot.volume }
end

function Inventory.maxStackVolume(id)
  local def = Items.get(id)
  return (def and def.maxStackVolume) or 100
end

function Inventory.unitVolume(id)
  local def = Items.get(id)
  return (def and def.unitVolume) or 1
end

function Inventory.mergeInto(dst, src)
  if isEmpty(src) then
    return true
  end

  if isEmpty(dst) then
    dst.id = src.id
    dst.volume = src.volume
    Inventory.clear(src)
    return true
  end

  if dst.id ~= src.id then
    return false
  end

  local maxStack = Inventory.maxStackVolume(dst.id)
  if dst.volume >= maxStack then
    return false
  end

  local room = maxStack - dst.volume
  local take = math.min(room, src.volume)
  dst.volume = dst.volume + take
  src.volume = src.volume - take
  if src.volume <= 0 then
    Inventory.clear(src)
  end

  return true
end

function Inventory.swap(a, b)
  local aId, aVol = a.id, a.volume
  a.id, a.volume = b.id, b.volume
  b.id, b.volume = aId, aVol
end

function Inventory.totalVolume(slots)
  local v = 0
  for i = 1, #slots do
    local s = slots[i]
    if s and s.id and (s.volume or 0) > 0 then
      v = v + s.volume
    end
  end
  return v
end

function Inventory.addToSlots(slots, id, volume)
  local remaining = volume or 0
  if not id or remaining <= 0 then
    return 0
  end

  local maxStack = Inventory.maxStackVolume(id)

  for i = 1, #slots do
    local s = slots[i]
    if s and s.id == id and (s.volume or 0) > 0 and s.volume < maxStack then
      local room = maxStack - s.volume
      local take = math.min(room, remaining)
      s.volume = s.volume + take
      remaining = remaining - take
      if remaining <= 0 then
        return 0
      end
    end
  end

  for i = 1, #slots do
    local s = slots[i]
    if s and Inventory.isEmpty(s) then
      local take = math.min(maxStack, remaining)
      s.id = id
      s.volume = take
      remaining = remaining - take
      if remaining <= 0 then
        return 0
      end
    end
  end

  return remaining
end

return Inventory
