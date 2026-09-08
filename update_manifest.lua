-- ============================================
-- UPDATE_MANIFEST.LUA - Managed update files
-- ============================================
return {
    version="20260908-1820",
    date="2026-09-08",
    description="Stable HUB input, persistent runtime contexts, transactional database and recipe-driven setup",
    protected="/home/eoh_data",
    files={
        "/home/autorun.lua","/home/eoh/eoh_core.lua","/home/eoh/context.lua","/home/eoh/scanner.lua",
        "/home/eoh/runtime.lua","/home/eoh/transposers.lua","/home/eoh/engine.lua","/home/eoh/diagnose.lua",
        "/home/eoh/main.lua","/home/eoh/recipes.lua","/home/hub/main.lua","/home/hub/gui.lua",
        "/home/hub/theme.lua","/home/hub/input.lua","/home/hub/registry.lua","/home/hub/database.lua",
        "/home/hub/setup.lua","/home/lib/config.lua","/home/lib/settings.lua","/home/lib/logger.lua",
        "/home/U.lua","/home/update_manifest.lua",
    },
    installer="/home/install_eoh.lua",
    changelog={
        "Centralized OpenComputers key_down handling; no physical polling/latches",
        "Persistent context per EOH shared by HUB and engine",
        "Detail telemetry uses cached runtime state; main screen refresh is lightweight",
        "Delete stops the EOH worker before removing the database record",
        "Registry writes are transactional and protected database writes have recovery",
        "Tier determines the recipe planet; AA explicitly selects Plasma versus H2/He",
        "Hardware ownership checks are centralized and existing EOH hardware is excluded",
        "Removed unrelated OpenOS init.lua from the project",
    },
    critical=true,
}
