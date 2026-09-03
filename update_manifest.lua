-- ============================================================
-- EOH Controller Update Manifest
-- ============================================================

return {
    version = "7.1",
    build = "Universal Update Core",

    -- Формат: remote — путь в GitHub, local — путь на OC.
    files = {
        { remote = "U.lua", local = "/home/U.lua" },
        { remote = "update_manifest.lua", local = "/home/update_manifest.lua" },
        { remote = "install_eoh.lua", local = "/home/install_eoh.lua" },
        { remote = "autorun.lua", local = "/home/autorun.lua" },

        { remote = "home/eoh/config.lua", local = "/home/eoh/config.lua" },
        { remote = "home/eoh/logger.lua", local = "/home/eoh/logger.lua" },
        { remote = "home/eoh/recipes.lua", local = "/home/eoh/recipes.lua" },
        { remote = "home/eoh/theme.lua", local = "/home/eoh/theme.lua" },
        { remote = "home/eoh/eoh_core.lua", local = "/home/eoh/eoh_core.lua" },
        { remote = "home/eoh/main.lua", local = "/home/eoh/main.lua" },

        { remote = "home/hub/config.lua", local = "/home/hub/config.lua" },
        { remote = "home/hub/registry.lua", local = "/home/hub/registry.lua" },
        { remote = "home/hub/main.lua", local = "/home/hub/main.lua" },
        { remote = "home/hub/setup.lua", local = "/home/hub/setup.lua" }
    },

    -- Устаревшие файлы, которые больше не входят в программу.
    remove = {
        "/home/hub/hub_config.lua"
    },

    -- Эти данные updater никогда не удаляет и не скачивает.
    protected = {
        "/home/eoh/settings.lua",
        "/home/eoh/registry.dat",
        "/home/eoh/logs/"
    }
}
