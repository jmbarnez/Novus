# Credits System - Integration Guide

## Quick Reference

### Get Player Credits
```lua
local playerEntities = ECS.getEntitiesWith({"Player"})
if #playerEntities > 0 then
    local wallet = ECS.getComponent(playerEntities[1], "Wallet")
    local credits = wallet and wallet.credits or 0
end
```

### Award Credits to Player
```lua
local function awardCredits(amount)
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        local wallet = ECS.getComponent(playerEntities[1], "Wallet")
        if wallet then
            wallet.credits = wallet.credits + amount
            print("Awarded " .. amount .. " credits!")
        end
    end
end
```

### Deduct Credits from Player
```lua
local function deductCredits(amount)
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        local wallet = ECS.getComponent(playerEntities[1], "Wallet")
        if wallet then
            if wallet.credits >= amount then
                wallet.credits = wallet.credits - amount
                return true  -- Transaction successful
            else
                return false  -- Insufficient funds
            end
        end
    end
end
```

## Common Use Cases

### 1. Reward for Destroying Enemies
**File to modify:** `src/systems/destruction.lua`

```lua
-- In the enemy destruction handler:
local destroyedShip = -- ... the destroyed entity
if ECS.hasComponent(destroyedShip, "CombatAI") then
    awardCredits(150)  -- Combat ships worth more
elseif ECS.hasComponent(destroyedShip, "MiningAI") then
    awardCredits(75)   -- Mining ships worth less
end
```

### 2. Selling Mined Materials
**File to create:** `src/systems/trading.lua` (new file)

```lua
local function sellResources()
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local cargo = ECS.getComponent(pilotId, "ControlledBy") 
            and ECS.getComponent(ECS.getComponent(pilotId, "ControlledBy").shipId, "Cargo")
        
        if cargo then
            local resources = cargo.items
            local totalValue = 0
            
            -- Define item values
            local itemPrices = {
                stone = 10,
                iron = 25,
                scrap = 50
            }
            
            for itemId, count in pairs(resources) do
                local price = itemPrices[itemId] or 5
                totalValue = totalValue + (price * count)
                resources[itemId] = nil  -- Remove from cargo
            end
            
            awardCredits(totalValue)
            return totalValue
        end
    end
end
```

### 3. Shopping System
**File to create:** `src/systems/shop.lua` (new file)

```lua
local Shop = {}

Shop.items = {
    ["advanced_mining_laser"] = {
        name = "Advanced Mining Laser",
        cost = 500,
        type = "turret_module"
    },
    ["shield_upgrade"] = {
        name = "Shield Upgrade",
        cost = 300,
        type = "upgrade"
    },
    ["speed_boost"] = {
        name = "Speed Boost Module",
        cost = 200,
        type = "upgrade"
    }
}

function Shop.buyItem(itemId)
    local item = Shop.items[itemId]
    if not item then return false, "Item not found" end
    
    local success = deductCredits(item.cost)
    if success then
        return true, item.name .. " purchased!"
    else
        return false, "Insufficient credits"
    end
end

return Shop
```

### 4. Display Credits in UI Window
**File to modify:** `src/ui/ship_window.lua`

```lua
-- Add to your UI rendering code:
function drawPlayerStats()
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        local wallet = ECS.getComponent(playerEntities[1], "Wallet")
        if wallet then
            love.graphics.print("Credits: " .. wallet.credits, x, y)
        end
    end
end
```

## Advanced Features

### Taxation System
```lua
local TAX_RATE = 0.05  -- 5% tax

local function applySaleTax(amount)
    local tax = math.floor(amount * TAX_RATE)
    return amount - tax, tax
end
```

### Credit Limits
```lua
local MAX_CREDITS = 1000000

local function awardCreditsWithCap(amount)
    local playerEntities = ECS.getEntitiesWith({"Player"})
    if #playerEntities > 0 then
        local wallet = ECS.getComponent(playerEntities[1], "Wallet")
        if wallet then
            wallet.credits = math.min(wallet.credits + amount, MAX_CREDITS)
        end
    end
end
```

### Transaction Logging
```lua
local transactionLog = {}

local function logTransaction(type, amount, reason)
    table.insert(transactionLog, {
        timestamp = love.timer.getTime(),
        type = type,  -- "earn", "spend"
        amount = amount,
        reason = reason
    })
end
```

## Testing

To test the credits system in-game:

1. **Check starting balance:**
   - Look at top-left HUD in the game
   - Should display "Credits: 1000"

2. **Test modifying credits:**
   - Open dev console (if available)
   - Run: `awardCredits(500)`
   - Verify HUD updates immediately

3. **Test persistence:**
   - Earn/spend credits in gameplay
   - Check that display updates smoothly
   - Verify no visual glitches

## Performance Considerations

- Credits display is cached in the HUD system (redraws only on change)
- No performance impact from displaying credits
- Wallet component is lightweight (single integer)
- Recommend using transactions sparingly (e.g., once per destroyed enemy, not per frame)

## File Dependencies

When implementing credit features, these files are important:

| System | File | Why |
|--------|------|-----|
| Display | `src/systems/hud.lua` | Shows credits on screen |
| Storage | `src/components/cargo.lua` | Defines Wallet component |
| Rewards | `src/systems/destruction.lua` | Enemy defeat handling (future) |
| Trading | `src/items/item_loader.lua` | Item pricing system (future) |
