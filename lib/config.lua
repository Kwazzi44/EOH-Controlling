-- ============================================
-- CONFIG.LUA - Общая конфигурация EOH Controller
-- ============================================

local config = {
    version = "20260906-2300",

    defaults = {
        tier = 3,
        mode = "production",
        useAA = false,
        overclocks = 0,
        autoRestart = true,
        tolerance = 0.001,
    },

    components = {
        eohController = nil,
        transposerHydrogen = nil,
        transposerHelium = nil,
        transposerPlasma = nil,
        transposerPlasmaList = {},
        transposers = {},
    },

    transposer = {
        transferRate = 1000,
        sourceSide = "north",
        targetSide = "south",
    },

    hubName = "EOH Controller Hub",
    maxEOH = 9,
}

return config
