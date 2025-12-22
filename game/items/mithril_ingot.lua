return {
    id = "mithril_ingot",
    name = "Mithril Ingot",
    color = { 0.28, 0.38, 0.60, 0.95 },
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
        shadow = { dx = 0.06, dy = 0.06, a = 0.34 },
        fillA = 0.94,
        outline = { a = 0.92, width = 1 },
        highlight = {
            kind = "polyline",
            points = {
                -0.30, -0.20,
                0.05, -0.35,
                0.35, -0.15,
            },
            a = 0.20,
            width = 1,
        },
        detail = {
            kind = "line",
            points = {
                -0.15, 0.05,
                0.20, 0.25,
            },
            a = 0.16,
            width = 1,
        },
    },
}
