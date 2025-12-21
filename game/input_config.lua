--- Centralized input configuration for baton
--- All game controls should be defined here

return {
    controls = {
        -- Movement
        thrust = { "key:w", "key:up" },
        strafe_left = { "key:a", "key:left" },
        strafe_right = { "key:d", "key:right" },
        brake = { "key:space" },

        -- Combat
        fire = { "mouse:1" },
        aim = { "mouse:2" },
        target_lock = { "key:lctrl", "key:rctrl" },
    },
}
