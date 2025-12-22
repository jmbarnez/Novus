return {
    id = "iron_ingot",
    name = "Iron Ingot",
    color = { 0.72, 0.72, 0.76, 0.95 },
    unitVolume = 1,
    maxStackVolume = 100,
    icon = {
        kind = "poly",
        points = {
            -0.50, -0.30,
            0.00, -0.50,
            0.50, -0.30,
            0.50, 0.30,
            0.00, 0.50,
            -0.50, 0.30,
        },
        shadow = { dx = 0.06, dy = 0.06, a = 0.32 },
        fillA = 0.94,
        outline = { a = 0.90, width = 1 },
        highlight = {
            kind = "polyline",
            points = {
                -0.30, -0.20,
                0.05, -0.35,
                0.35, -0.15,
            },
            a = 0.22,
            width = 1,
        },
        detail = {
            kind = "line",
            points = {
                -0.15, 0.05,
                0.20, 0.25,
            },
            a = 0.18,
            width = 1,
        },
    },
}
