-- ============================================
-- CONFIG.LUA - Общая конфигурация EOH Controller
-- ============================================

local config = {
    version = "1.0",
    
    -- Настройки по умолчанию для EOH
    defaults = {
        tier = 3,
        mode = "production",
        useAA = false,
        overclocks = 0,
        autoRestart = true,
        tolerance = 0.001,
    },
    
    -- Компоненты (заполняются при сканировании)
    components = {
        eohController = nil,
        transposerHydrogen = nil,
        transposerHelium = nil,
        transposerPlasma = nil,
        transposerPlasmaList = {},
        transposers = {},
    },
    
    -- Настройки транспозера
    transposer = {
        transferRate = 1000,
        sourceSide = "north",
        targetSide = "south",
    },
    
    -- Настройки HUB
    hubName = "EOH Controller Hub",
    maxEOH = 9,
}

return config
