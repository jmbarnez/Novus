# Asteroid Mass and Physics Scaling

## Overview
Asteroids are now significantly heavier and have much greater rotational inertia, making them resistant to being knocked around by the drone.

---

## Mass Scaling

### Formula: `asteroidMass = size * size * 0.5`

### Examples:
| Size (px) | Mass | Notes |
|-----------|------|-------|
| 20        | 200  | Small asteroid, 200× drone mass |
| 40        | 800  | Medium asteroid, 800× drone mass |
| 60        | 1800 | Large asteroid, 1800× drone mass |

**Drone mass** = 1 (for comparison)

### Physics Impact:
- **Momentum conservation**: `p = m × v`
  - Drone (m=1, v=300): momentum = 300
  - Large asteroid (m=1800, v=20): momentum = 36,000
  - Drone can't push asteroid easily!

- **Velocity change on collision**:
  ```
  Δv = impulse / mass
  Asteroid (mass=1800): Δv = impulse / 1800  (very small change)
  Drone (mass=1): Δv = impulse / 1  (large change)
  ```

---

## Rotational Inertia Scaling

### Formula: `rotationalInertia = size * size * size * 2`

### Examples:
| Size (px) | Inertia | Notes |
|-----------|---------|-------|
| 20        | 16,000  | Extreme resistance to rotation |
| 40        | 128,000 | Very hard to spin |
| 60        | 432,000 | Massive resistance |

### Physics Impact:
- **Angular impulse**: `Δω = torque / inertia`
  - Large asteroid: Δω = torque / 432,000 (imperceptible spin)
  - Drone: Δω = torque / 1.5 (easily spins)

- **Why cubic scaling?**:
  - Real-world moment of inertia scales with r⁵ for solid spheres
  - We use r³ (cubic) for asteroids as a simplified model
  - Approximates how hard it is to spin something massive

---

## Collision Dynamics Example

### Scenario: Drone hits asteroid at 300 u/s

**Before Update**:
- Asteroid would spin dramatically
- Asteroid mass = 1 (same as drone)
- Easy to deflect asteroids

**After Update**:
- Asteroid barely moves (mass = 200-1800×)
- Asteroid barely spins (inertia = 16,000-432,000×)
- Drone bounces back significantly
- Feels like hitting a brick wall

### Physics Calculation:

```
Drone:    mass = 1,    velocity = 300 u/s
Asteroid: mass = 1000, velocity = 10 u/s

After collision (perfectly elastic):
v_drone_after = ((1-1000) * 300 + (2*1000) * 10) / (1+1000)
              = (-997*300 + 2000*10) / 1001
              ≈ -298 u/s (bounces back!)

v_asteroid_after = ((1000-1) * 10 + (2*1) * 300) / (1+1000)
                 = (999*10 + 600) / 1001
                 ≈ 10.59 u/s (barely affected)
```

---

## Rotational Response

### Angular Impulse on Off-Center Hit:

```
Torque = r_perp × J  (cross product)

For large asteroid (Inertia = 432,000):
Δω = torque / 432,000

For drone (Inertia = 1.5):
Δω = torque / 1.5
```

**Result**: Drone can spin 288,000× more easily than a large asteroid!

---

## Player Feedback

### What the Player Experiences:
1. **Light touch**: Asteroid doesn't move much, drone bounces back
2. **High-speed impact**: Even at max speed, asteroids are immovable objects
3. **Spinning**: Drone spins from off-center hits, but asteroids barely rotate
4. **Momentum battles**: Must carefully approach moving asteroids
5. **Physics feels "heavy"**: Asteroids feel like real massive rocks

### Game Balance:
- Asteroids are obstacles, not easily moved
- Drone's mobility is advantage against heavy asteroids
- Speed and agility matter more than raw force
- Makes mining strategy more interesting (approach angles matter)

---

## Size Variation Effect

### Small Asteroid (size=20):
- Mass = 200
- Inertia = 16,000
- Easiest to deflect, but still 200× heavier than drone

### Medium Asteroid (size=40):
- Mass = 800
- Inertia = 128,000
- Significantly more massive and resistant

### Large Asteroid (size=60):
- Mass = 1,800
- Inertia = 432,000
- Nearly immovable at normal speeds

---

## Impact on Gameplay

### Mining Considerations:
- Need to position carefully to hit asteroids effectively
- Approach from stable angle to avoid spinning
- Understand that asteroids won't move on impact

### Collision Avoidance:
- Asteroids are walls, not bouncy balls
- Need to dodge rather than push through
- High-speed impacts bounce drone back significantly

### Physics Realism:
- Matches real asteroid physics (extremely dense rock in space)
- Creates tension and challenge in flight
- Makes collisions feel consequential

---

## Tuning Notes

If asteroids need adjustment:

1. **Too heavy?** Reduce the mass multiplier:
   ```lua
   local asteroidMass = size * size * 0.1  -- Lighter version
   ```

2. **Too resistant to spin?** Reduce rotational inertia:
   ```lua
   local rotationalInertia = size * size * 0.5  -- Much lighter
   ```

3. **Want size variation?** Add random density:
   ```lua
   local density = 0.3 + math.random() * 0.4  -- 0.3-0.7
   local asteroidMass = size * size * density
   ```

4. **Want momentum conservation?** Use:
   ```lua
   local asteroidMass = size * size * size * 0.01  -- Cubic for volume-based mass
   ```

---

## Technical Details

### Mass Component:
```lua
Physics = Components.Physics(0.999, 100, asteroidMass)
          -- (friction, max_speed, mass)
```

### Rotational Component:
```lua
RotationalMass = Components.RotationalMass(rotationalInertia)
                 -- Moment of inertia for Δω = τ / I
```

### Collision Response:
```lua
-- Linear impulse magnitude
j = -(1 + e) * velAlongNormal / (1/mass1 + 1/mass2)

-- Angular impulse magnitude
Δω = (r × J) / inertia
```

