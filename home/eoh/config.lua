-- ============================================================
-- EOH CONTROLLER - CONFIG
-- ============================================================

local config = {}

config.gui_refresh = 0.5
config.poll_interval = 1.0
config.log_file = "/home/eoh/logs/eoh.log"
config.log_max_bytes = 1024 * 1024

-- Настройки режима Production.
config.planet_tier = 1
config.use_astral_arrays = false
config.overclocks = 0
config.auto_restart = true
config.fluid_tolerance = 0.001

-- Автоопределение оборудования.
config.auto_scan = true
config.require_two_transposers = true

-- Параметры транспозеров. Адреса НЕ прописываем вручную:
-- контроллер ищет их по подключённым сторонам.
config.transposer = {
    eoh_side = 3,
    fluid_interface_side_1 = 4,
    fluid_interface_side_2 = 1,
    hydrogen_tank = 1,
    helium_tank = 2,
    plasma_tank = 3
}

return config
