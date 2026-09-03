-- ============================================================
-- EOH CONTROLLER - CONFIG
-- ============================================================

local config = {}

-- Интервалы интерфейса и обновления состояния.
config.gui_refresh = 0.5
config.poll_interval = 0.5

-- Логирование.
config.log_file = "/home/eoh/logs/eoh.log"
config.log_max_bytes = 1024 * 1024

-- Настройки Production Mode.
config.planet_tier = 1
config.use_astral_arrays = false
config.overclocks = 0
config.auto_restart = true
config.fluid_tolerance = 0.001

-- Автопоиск оборудования.
config.auto_scan = true
config.require_two_transposers = true

-- ВАЖНО: Phase 2 по умолчанию только рассчитывает подачу.
-- Реальный transferFluid будет запрещён, пока этот флаг не включён.
config.allow_fluid_transfer = false

-- Физическая схема, подтверждённая диагностикой.
config.transposer = {
    eoh_side = 3,
    fluid_interface_side_1 = 4,
    fluid_interface_side_2 = 1,
    hydrogen_tank = 1,
    helium_tank = 2,
    plasma_tank = 3
}

return config
