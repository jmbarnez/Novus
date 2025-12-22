return {
    id = "iron_ingot",
    name = "Iron Ingot",
    color = { 0.72, 0.72, 0.76, 0.95 },
    unitVolume = 1,
    maxStackVolume = 100,
    icon = {
        kind = "poly",
        points = {
            -0.60, -0.22,
            -0.18, -0.40,
            0.62, -0.22,
            0.62, 0.22,
            0.18, 0.40,
            -0.60, 0.22,
        },
        shadow = { dx = 0.06, dy = 0.06, a = 0.32 },
        fillA = 0.94,
        outline = { a = 0.90, width = 1 },
        highlight = {
            kind = "polyline",
            points = {
                -0.40, -0.15,
                -0.05, -0.32,
                0.40, -0.20,
            },
            a = 0.65,
            width = 2,
        },
        detail = {
            kind = "line",
            points = {
                -0.50, 0.05,
                0.50, -0.08,
            },
            a = 0.55,
            width = 1.5,
        },
    },
}
