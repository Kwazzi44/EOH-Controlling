-- ============================================================
-- RECIPES.LUA - БАЗА РЕЦЕПТОВ EOH
-- Только данные. Логика находится в eoh_core.lua.
-- Значения сохранены из предоставленной базы рецептов.
-- ============================================================

local recipes = {
    [1] = {
        planet = "Overworld",
        hydrogen = 1000000000,
        helium = 1000000000,
        plasma = 12400,
        duration = 2250,
        starMatter = "WDM",
        display = "T1 Overworld (WDM)"
    },
    [2] = {
        planet = "Mars",
        hydrogen = 2000000000,
        helium = 2000000000,
        plasma = 24800,
        duration = 4409,
        starMatter = "WDM",
        display = "T2 Mars (WDM)"
    },
    [3] = {
        planet = "Ceres",
        hydrogen = 3000000000,
        helium = 3000000000,
        plasma = 37200,
        duration = 6173,
        starMatter = "WDM",
        display = "T3 Ceres (WDM)"
    },
    [4] = {
        planet = "Io",
        hydrogen = 4000000000,
        helium = 4000000000,
        plasma = 49600,
        duration = 7921,
        starMatter = "BDM",
        display = "T4 Io (BDM)"
    },
    [5] = {
        planet = "Titan",
        hydrogen = 5000000000,
        helium = 5000000000,
        plasma = 62000,
        duration = 9650,
        starMatter = "BDM",
        display = "T5 Titan (BDM)"
    },
    [6] = {
        planet = "Proteus",
        hydrogen = 6000000000,
        helium = 6000000000,
        plasma = 74400,
        duration = 11375,
        starMatter = "BDM",
        display = "T6 Proteus (BDM)"
    },
    [7] = {
        planet = "Pluto",
        hydrogen = 7000000000,
        helium = 7000000000,
        plasma = 86800,
        duration = 13122,
        starMatter = "Universium",
        display = "T7 Pluto (Universium)"
    },
    [8] = {
        planet = "Vega B",
        hydrogen = 8000000000,
        helium = 8000000000,
        plasma = 99200,
        duration = 14855,
        starMatter = "Universium",
        display = "T8 Vega B (Universium)"
    },
    [9] = {
        planet = "Deep Dark",
        hydrogen = 10000000000,
        helium = 10000000000,
        plasma = 124000,
        duration = 16585,
        starMatter = "Universium",
        display = "T9 Deep Dark (Universium, 10B)"
    }
}

function recipes.get(tier)
    return recipes[tonumber(tier)]
end

function recipes.getAll()
    return recipes
end

function recipes.getAvailableTiers()
    local tiers = {}
    for tier, _ in pairs(recipes) do
        table.insert(tiers, tier)
    end
    table.sort(tiers)
    return tiers
end

return recipes
