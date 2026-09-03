-- ============================================================
-- EOH CONTROLLER - CONFIG / PHASE 3
-- ============================================================

local config = {}

config.gui_refresh = 0.25
config.poll_interval = 0.5

config.log_file = "/home/eoh/logs/eoh.log"
config.log_max_bytes = 1024 * 1024

-- Производственный режим.
config.planet_tier = 1
config.use_astral_arrays = false
config.overclocks = 0
config.auto_restart = true
config.fluid_tolerance = 0.001

-- Поиск оборудования.
config.auto_scan = true
config.require_two_transposers = true

-- ВАЖНО: по умолчанию реальные переливы выключены.
config.allow_fluid_transfer = false

-- Ручной тестовый объём.
-- По умолчанию ровно один буфер Fluid Interface.
config.fill_test_amount = 16000

-- Защита и параметры поточной подачи.
-- Эти значения используются ТОЛЬКО для будущего автоматического режима.
-- Они не означают, что EOH должен быть заполнен до target перед рецептом.
config.fluid_control = {
    min_trigger = 8000000,
    target_level = 16000000,
    max_transfer_per_call = 16000000,
    verification_delay = 0.05,
    max_no_progress_attempts = 3
}

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
