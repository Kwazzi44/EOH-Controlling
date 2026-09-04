-- ============================================
-- CALCULATOR.LUA - Калькулятор рецептов
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;" .. package.path

local recipes = require("recipes")
local core = require("eoh_core")

function calculateRecipe(tier, useAA, overclocks)
    local recipe = recipes.get(tier)
    if not recipe then
        return nil, "Неизвестный тир"
    end
    local result = {
        planet = recipe.planet,
        starMatter = recipe.starMatter,
        hydrogen = useAA and 0 or recipe.hydrogen,
        helium = useAA and 0 or recipe.helium,
        plasma = useAA and recipe.plasma or 0,
        duration = recipe.duration,
    }
    return result
end

function formatRecipeInfo(recipe)
    if not recipe then return "Рецепт не найден" end
    local lines = {}
    table.insert(lines, "🌍 Планета: " .. recipe.planet)
    table.insert(lines, "📦 Тип: " .. recipe.starMatter)
    if recipe.hydrogen > 0 then
        table.insert(lines, "💧 Водород: " .. core.formatNumber(recipe.hydrogen) .. "L")
    end
    if recipe.helium > 0 then
        table.insert(lines, "💧 Гелий: " .. core.formatNumber(recipe.helium) .. "L")
    end
    if recipe.plasma > 0 then
        table.insert(lines, "💧 Плазма: " .. core.formatNumber(recipe.plasma) .. "L")
    end
    return table.concat(lines, "\n")
end

return {
    calculateRecipe = calculateRecipe,
    formatRecipeInfo = formatRecipeInfo,
}