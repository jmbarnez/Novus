# Credits System Implementation

## Overview
The Credits system is a simple currency mechanism integrated into the game using the ECS architecture. Players start with a base amount and can earn more by defeating enemies.

## Implementation Details

### 1. **Wallet Component** (`src/components/cargo.lua`)
- Added `Wallet` component to track player currency
- Stores `credits` field with current balance
- Created with initial amount (e.g., 1000 credits at game start)

```lua
Components.Wallet = function(credits)
    return {
        credits = credits or 0
    }
end
```

### 2. **Player Initialization** (`src/core.lua`)
- Player entity now receives a `Wallet` component on creation
- Initial value: **1000 credits**
- Location: Pilot creation in `Core.init()` function

```lua
ECS.addComponent(pilotId, "Wallet", Components.Wallet(1000))
```

### 3. **HUD Display** (`src/systems/hud.lua`)
- Added `drawCreditsDisplay()` function
- Displays current credits in top-left corner, below health bar
- Updates dynamically as credits change
- Integrated into HUD state hash for efficient rendering

**Location on screen:**
- Top-left corner (same area as turret slots)
- Below the health/shield bar
- Format: `Credits: XXXX`

### 4. **Modifications Made**
| File | Changes |
|------|---------|
| `src/components/cargo.lua` | Added `Wallet` component definition |
| `src/core.lua` | Added Wallet component to player initialization |
| `src/systems/hud.lua` | Added credit display function and integrated into HUD |

## Usage

### Modifying Credits
To modify player credits in code:

```lua
local playerEntities = ECS.getEntitiesWith({"Player"})
local pilotId = playerEntities[1]
local wallet = ECS.getComponent(pilotId, "Wallet")

-- Add credits
wallet.credits = wallet.credits + 100

-- Subtract credits
wallet.credits = wallet.credits - 50

-- Set directly
wallet.credits = 5000
```

## Future Extensions

### Recommended additions:
1. **Enemy Rewards** - Award credits when destroying enemies
   - Different enemy types award different amounts
   - Add to destruction system

2. **Shopping System** - Allow players to spend credits
   - Purchase items, upgrades, ship components
   - Create UI for shops

3. **Trade System** - Exchange items for credits
   - Sell resources to merchants
   - Dynamic pricing based on rarity

4. **Audio/Notifications** - Feedback when earning/spending
   - Sound effects on credit transactions
   - Notifications for large gains

5. **Inventory Value** - Items have credit values
   - Auto-sell salvage for credits
   - Valuation system for equipment

## Debugging

To check player's current credits in console/logs:
```lua
local playerEntities = ECS.getEntitiesWith({"Player"})
if #playerEntities > 0 then
    local wallet = ECS.getComponent(playerEntities[1], "Wallet")
    if wallet then
        print("Player credits: " .. wallet.credits)
    end
end
```

## Design Rationale

**Why this approach:**
- **ECS-native**: Fits perfectly with existing component system
- **Simple**: Minimal code, easy to understand
- **Scalable**: Easy to add shops, rewards, taxes, etc.
- **Non-invasive**: Doesn't require major refactoring
- **Performance**: Credits display uses efficient HUD caching system
