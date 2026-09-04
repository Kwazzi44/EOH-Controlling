-- ============================================
-- RECIPES.LUA - База данных рецептов
-- ============================================

local recipes = {
    [1] = {planet = "Overworld", hydrogen = 1e9, helium = 1e9, plasma = 12400, starMatter = "WDM", display = "T1 Overworld (WDM)"},
    [2] = {planet = "Mars", hydrogen = 2e9, helium = 2e9, plasma = 24800, starMatter = "WDM", display = "T2 Mars (WDM)"},
    [3] = {planet = "Ceres", hydrogen = 3e9, helium = 3e9, plasma = 37200, starMatter = "WDM", display = "T3 Ceres (WDM)"},
    [4] = {planet = "Io", hydrogen = 4e9, helium = 4e9, plasma = 49600, starMatter = "BDM", display = "T4 Io (BDM)"},
    [5] = {planet = "Titan", hydrogen = 5e9, helium = 5e9, plasma = 62000, starMatter = "BDM", display = "T5 Titan (BDM)"},
    [6] = {planet = "Proteus", hydrogen = 6e9, helium = 6e9, plasma = 74400, starMatter = "BDM", display = "T6 Proteus (BDM)"},
    [7] = {planet = "Pluto", hydrogen = 7e9, helium = 7e9, plasma = 86800, starMatter = "Universium", display = "T7 Pluto (Universium)"},
    [8] = {planet = "Vega B", hydrogen = 8e9, helium = 8e9, plasma = 99200, starMatter = "Universium", display = "T8 Vega B (Universium)"},
    [9] = {planet = "Deep Dark", hydrogen = 10e9, helium = 10e9, plasma = 124000, starMatter = "Universium", display = "T9 Deep Dark (Universium, 10B)"},
}

function recipes.get(tier)
    return recipes[tier]
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