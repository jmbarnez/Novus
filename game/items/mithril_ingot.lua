return {
    id = "mithril_ingot",
    name = "Mithril Ingot",
    color = { 0.28, 0.38, 0.60, 0.95 },
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
        shadow = { dx = 0.06, dy = 0.06, a = 0.34 },
        fillA = 0.94,
        outline = { a = 0.92, width = 1 },
        highlight = {
            kind = "polyline",
            points = {
                -0.42, -0.15,
                -0.08, -0.34,
                0.42, -0.18,
            },
            a = 0.70,
            width = 2,
        },
        detail = {
            kind = "line",
            points = {
                -0.50, 0.05,
                0.50, -0.08,
            },
            a = 0.60,
            width = 1.5,
        },
    },
}
