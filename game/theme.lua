local Theme = {}

Theme.hud = {
  layout = {
    margin = 16,
    stackGap = 18,
    smallGap = 6,
  },

  panelStyle = {
    radius = 3,
    borderWidth = 1,
    shadowOffset = 2,
    shadowAlpha = 0.35,
  },

  controls = {
    pad = 8,
    gap = 2,
    textAlpha = 0.85,
  },

  targetPanel = {
    w = 240,
    h = 62,
    pad = 8,
    barH = 8,
    titleYOffset = -2,
    barYOffset = 6,
    hpTextGap = 2,
    healthFill = { 1.00, 0.90, 0.20, 0.90 },
  },

  cursorCooldown = {
    w = 17,
    h = 4,
    bottomOffset = 44,
    fillAlpha = 0.98,
  },

  waypointIndicator = {
    edgeInset = 42,
    arrowOuterPoly = { 0, 0, -16, 9, -11, 0, -16, -9 },
    arrowInnerPoly = { 0, 0, -15, 8, -10, 0, -15, -8 },
    labelClampPad = 6,
    labelYOffset = 12,
    labelTextAlpha = 0.90,
    labelShadowAlpha = 0.85,
  },

  cargoPanel = {
    pad = 6,
    headerH = 24,
    footerH = 26,
    slot = 44,
    gap = 6,
    barGap = 6,
    barH = 10,
    closeSize = 18,
    closePad = 6,
    warnFrac = 0.85,
    dangerFrac = 0.95,
  },

  fullscreenMap = {
    legendW = 260,
    minMapW = 200,
    gridTargetPx = 110,
    gridInfoW = 176,
    gridInfoH = 38,
    gridInfoPadX = 12,
    gridInfoPadY = 10,

    waypointLineAlpha = 0.18,
    waypointCrossHalf = 8,
    waypointCrossLineWidth = 2,
    waypointLabelShadowAlpha = 0.75,
    waypointLabelTextAlpha = 0.85,
    waypointLabelOffsetX = 10,
    waypointLabelOffsetY = -10,
    waypointLabelShadowOffset = 1,

    legend = {
      swatchSize = 12,
      swatchInsetY = 4,
      swatchBorderAlpha = 0.35,
      swatchAlpha = 0.90,
      rowGap = 18,
      textX = 18,
      player = { 0.20, 0.65, 1.00 },
      asteroid = { 1.00, 1.00, 1.00 },
      pickup = { 0.35, 1.00, 0.45 },
      ship = { 1.00, 0.65, 0.20 },
    },
  },

  cursorReticle = {
    active = { 0.20, 0.85, 1.00, 0.95 },
    inactive = { 0.70, 0.70, 0.70, 0.75 },
    lineWidth = 2,
    glowAlpha = 0.18,
    len = 7,
    gap = 3,
    pulseBase = 0.7,
    pulseAmp = 0.3,
    pulseFreq = 10.0,
  },

  cursorUi = {
    poly = { 0, 0, 0, 16, 4, 12, 6, 20, 10, 18, 8, 10, 14, 10 },
    scale = 1.0,
    shadowAlpha = 0.70,
    fill = { 0.20, 0.85, 1.00, 1.00 },
    outline = { 0.00, 0.00, 0.00, 1.00 },
    fillAlpha = 0.95,
    outlineAlpha = 0.95,
    outlineWidth = 2,
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

    circleRadius = 18,
    circleThickness = 3,
    barW = 80,
    barH = 6,
    barGap = 4,
    panelPad = 6,

    xpFill = { 0.90, 0.75, 0.20, 0.90 },
    xpBg = { 0.30, 0.30, 0.30, 0.50 },
    hullFill = { 0.90, 0.40, 0.20, 0.85 },
    shieldFill = { 0.20, 0.80, 0.90, 0.85 },
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
    panelBorder = { 0.45, 0.85, 1.00, 0.22 },
    panelAccent = { 0.20, 0.85, 1.00, 0.12 },
    divider = { 0.45, 0.85, 1.00, 0.28 },

    accent = { 0.20, 0.85, 1.00, 0.95 },
    accentSoft = { 0.20, 0.85, 1.00, 0.70 },

    barBg = { 0, 0, 0, 0.35 },
    barBorder = { 0.45, 0.85, 1.00, 0.35 },

    barFillPrimary = { 1, 1, 1, 0.85 },
    barFillSecondary = { 1, 1, 1, 0.65 },

    text = { 1, 1, 1, 0.95 },
    textShadow = { 0, 0, 0, 0.80 },

    fpsText = { 1.00, 0.90, 0.20, 0.90 },
    fpsBrackets = { 1, 1, 1, 0.25 },

    minimapBg = { 0, 0, 0, 0.45 },
    minimapBorder = { 0.45, 0.85, 1.00, 0.22 },
    minimapGrid = { 1, 1, 1, 0.08 },
    minimapPlayer = { 0.20, 0.65, 1.00, 1.0 },

    good = { 0.20, 0.95, 0.35, 0.80 },
    warn = { 0.95, 0.85, 0.20, 0.85 },
    danger = { 0.95, 0.30, 0.25, 0.85 },

    pickup = { 0.35, 1.00, 0.45, 0.85 },
    ship = { 1.00, 0.65, 0.20, 0.55 },
    asteroid = { 1.00, 1.00, 1.00, 0.45 },

    debugText = { 1, 1, 1, 0.90 },
  },
}

return Theme
