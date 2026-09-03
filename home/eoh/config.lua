-- ============================================================
-- EOH CONTROLLER - DEFAULT CONFIG
-- ============================================================
-- ВАЖНО: этот файл содержит только значения по умолчанию.
-- Пользовательские настройки хранятся в settings.lua и не
-- обновляются через U.lua.
-- ============================================================

local config = {}

config.gui_refresh = 0.5
config.poll_interval = 1.0

config.log_file = "/home/eoh/logs/eoh.log"
config.log_max_bytes = 1024 * 1024
config.registry_file = "/home/eoh/registry.dat"
config.settings_file = "/home/eoh/settings.lua"

-- Реальная передача по умолчанию выключена до подтверждения.
config.allow_fluid_transfer = false

-- Безопасность дозировки.
config.max_transfer_attempts = 10000
config.verification_delay = 0.05
config.progress_poll = 0.5

-- Минимально допустимый запас перед стартом потока.
config.minimum_reservoir_fraction = 0.0

return config
