-- ============================================
-- UPDATE_MANIFEST.LUA - Манифест обновлений
-- ============================================

return {
    version = "20260905-1500",
    date = "2026-09-05",
    description = "Оптимизация производительности + исправление ошибок",
    files = {
        "/home/eoh/eoh_core.lua",
        "/home/eoh/diagnose.lua",
        "/home/eoh/main.lua",
        "/home/eoh/recipes.lua",
        "/home/hub/main.lua",
        "/home/hub/gui.lua",
        "/home/hub/registry.lua",
        "/home/hub/setup.lua",
        "/home/hub/theme.lua",
        "/home/lib/config.lua",
        "/home/lib/settings.lua",
        "/home/lib/logger.lua",
        "/home/autorun.lua",
        "/home/U.lua",
        "/home/update_manifest.lua",
    },
    changelog = {
        "Исправлен путь общей конфигурации и logger-модулей.",
        "Убрано случайное назначение gt_machine в качестве EOH.",
        "Убрано случайное назначение transposer для Hydrogen/Helium.",
        "sourceSide/targetSide теперь являются явными сторонами передачи.",
        "Добавлен cooperative scheduler для AUTO-циклов без блокировки HUB.",
        "Исправлена работа нескольких EOH без общего глобального binding.",
        "Добавлен отсутствовавший hub/theme.lua.",
        "Удалён дублирующий UI: eoh/main.lua стал compatibility launcher.",
        "Синхронизирован installer и update manifest.",
    },
    critical = false,
}
