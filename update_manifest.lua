-- ============================================
-- UPDATE_MANIFEST.LUA - Манифест обновлений
-- ============================================

return {
    version = "20260906-2300",
    date = "2026-09-06",
    description = "Protected user database, hardware ownership, setup/GUI refactor and staged installer",
    files = {
        "/home/autorun.lua",
        "/home/eoh/eoh_core.lua",
        "/home/eoh/context.lua",
        "/home/eoh/scanner.lua",
        "/home/eoh/runtime.lua",
        "/home/eoh/transposers.lua",
        "/home/eoh/engine.lua",
        "/home/eoh/diagnose.lua",
        "/home/eoh/main.lua",
        "/home/eoh/recipes.lua",
        "/home/hub/main.lua",
        "/home/hub/gui.lua",
        "/home/hub/theme.lua",
        "/home/hub/registry.lua",
        "/home/hub/database.lua",
        "/home/hub/setup.lua",
        "/home/lib/config.lua",
        "/home/lib/settings.lua",
        "/home/lib/logger.lua",
        "/home/U.lua",
        "/home/update_manifest.lua",
    },
    changelog = {
        "✅ Персональный context для каждого EOH",
        "✅ Убран опасный fallback случайных компонентов",
        "✅ Transposer использует только настроенную source/target сторону",
        "✅ Добавлен cooperative scheduler для AUTO",
        "✅ Core разделён на context/scanner/runtime/transposers/engine",
        "✅ Исправлена структура package.path",
        "✅ Setup позволяет вручную выбрать нераспознанный transposer",
        "✅ Пользовательская database вынесена из обновляемых каталогов",
        "✅ Installer обновляет только EOH-файлы и сохраняет пользовательскую database",
    },
    critical = false,
}
