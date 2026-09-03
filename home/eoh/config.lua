-- config.lua
-- Настройки EOH Controller.
--
-- ВАЖНО: репозиторий и данные рецептов нужно привести к вашему реальному
-- проекту/вики GTNH. Структура уже подготовлена для дальнейшего заполнения.

local config = {}

config.projectName = "EOH Controller"
config.version = "1.0.0"

-- Базовый путь установки в OC/Linux.
config.rootDir = "/home/eoh"
config.logDir = config.rootDir .. "/logs"
config.backupDir = config.rootDir .. "/backup"
config.logFile = config.logDir .. "/eoh.log"
config.maxLogSize = 1024 * 1024 -- 1 МБ
config.logHistoryLines = 20

-- Ссылка на репозиторий. Замените на фактический URL своего проекта.
config.repoBaseUrl = "https://raw.githubusercontent.com/USER/REPO/main/home/eoh"

-- Интервалы обновления интерфейса.
config.uiRefreshDelay = 0.2
config.statusPollDelay = 1.0
config.scanRetryDelay = 2.0

-- Допуск по жидкости.
config.defaultTolerance = 0.001 -- 0.1%

-- Настройки по умолчанию.
config.defaults = {
  tier = 1,
  useAA = false,
  overclocks = 0,
  autoRestart = true,
  tolerance = config.defaultTolerance,
  mode = "production",
}

-- Названия и шаблоны компонентов, которые ищем автоматически.
config.componentPatterns = {
  eohController = {
    "eyeofharmony",
    "eye_of_harmony",
    "eoh",
    "harmony",
  },
  transposer = {
    "transposer",
  },
}

-- Стороны по умолчанию для трансопозеров.
-- При необходимости можно вручную подстроить под вашу сборку.
config.defaultSides = {
  input = 0,
  output = 1,
  plasmaInput = 2,
  buffer = 3,
}

-- Путь к файлу автозапуска внутри проекта.
config.autorunFile = config.rootDir .. "/autorun.lua"

-- Имя файлов, которые скачиваются при обновлении.
config.packageFiles = {
  "main.lua",
  "gui.lua",
  "eoh_core.lua",
  "recipes.lua",
  "config.lua",
  "logger.lua",
  "theme.lua",
  "install_eoh.lua",
  "update_eoh.lua",
}

-- Встроенные команды меню.
config.menuKeys = {
  ["1"] = "production",
  ["2"] = "power",
  ["3"] = "settings",
  ["4"] = "status",
  ["5"] = "scan",
  ["6"] = "logs",
  ["7"] = "update",
  ["q"] = "quit",
  ["Q"] = "quit",
}

return config
