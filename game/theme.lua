local Theme = {}

Theme.hud = {
  layout = {
    margin = 16,
    stackGap = 18,
    smallGap = 6,
  },

  statusPanel = {
    w = 320,
    h = 62,
    pad = 10,
    dividerFrac = 0.58,
    dividerInset = 8,
    topAccentHeight = 2,

    xpH = 18,
    rightBarH = 10,
    rightGap = 8,
  },

  minimap = {
    w = 140,
    h = 140,
    gridInset = 5,
    playerDotRadius = 2.5,
  },

  fps = {
    bracketOffsetX = 8,
    bracketInsetY = 2,
  },

  colors = {
    panelBg = { 0, 0, 0, 0.30 },
    panelBorder = { 1, 1, 1, 0.28 },
    panelAccent = { 1, 1, 1, 0.12 },
    divider = { 1, 1, 1, 0.35 },

    barBg = { 0, 0, 0, 0.35 },
    barBorder = { 1, 1, 1, 0.45 },

    barFillPrimary = { 1, 1, 1, 0.85 },
    barFillSecondary = { 1, 1, 1, 0.65 },

    text = { 1, 1, 1, 0.95 },
    textShadow = { 0, 0, 0, 0.80 },

    fpsText = { 1.00, 0.90, 0.20, 0.90 },
    fpsBrackets = { 1, 1, 1, 0.25 },

    minimapBg = { 0, 0, 0, 0.45 },
    minimapBorder = { 1, 1, 1, 0.28 },
    minimapGrid = { 1, 1, 1, 0.08 },
    minimapPlayer = { 0.20, 0.65, 1.00, 1.0 },

    debugText = { 1, 1, 1, 0.90 },
  },
}

return Theme
