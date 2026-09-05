-- ============================================
-- UPDATE_MANIFEST.LUA - Манифест обновлений
-- ============================================

return {
    version = "20260904-1494",
    date = "2026-09-04",
    description = "Оптимизация производительности + исправление ошибок",
    files = {
        -- EOH Controller
        "/home/eoh/config.lua",
        "/home/eoh/eoh_config.lua",
        "/home/eoh/eoh_core.lua",
        "/home/eoh/diagnose.lua",
        "/home/eoh/main.lua",
        "/home/eoh/recipes.lua",
        "/home/eoh/settings.lua",
        "/home/eoh/theme.lua",
        -- HUB
        "/home/hub/config.lua",
        "/home/hub/theme.lua",
        "/home/hub/main.lua",
        "/home/hub/gui.lua",
        "/home/hub/registry.lua",
        "/home/hub/setup.lua",
        -- Shared library
        "/home/lib/logger.lua",
        -- Root files
        "/autorun.lua",
        "/U.lua",
        "/init.lua",
        "/README.md",
    },
    changelog = {
        "✅ Исправлен модуль thread -> coroutine",
        "✅ Синхронизированы версии CORE_BUILD",
        "✅ Logger вынесен в /home/lib/",
        "✅ Удалён неиспользуемый calculator.lua",
        "✅ Добавлена обработка ошибок при загрузке конфигов",
        "✅ Оптимизирована производительность (кэширование GUI, dirty flags)",
        "✅ Устранены лаги интерфейса",
        "✅ Улучшена проверка компонентов",
    },
    critical = false,
}
