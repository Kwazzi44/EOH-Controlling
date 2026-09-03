-- recipes.lua
-- База данных рецептов EOH.
--
-- ВНИМАНИЕ: значения для T1-T8 необходимо сверить с вики GTNH и вашими
-- внутриигровыми данными. Здесь уже подготовлена структура и отдельный
-- точный рецепт Deep Dark T9.

local recipes = {}

local function makeRecipe(tier, planetName, matterType, hydrogen, helium, plasma, duration, notes)
  return {
    tier = tier,
    planet = planetName,
    matter = matterType,
    hydrogen = hydrogen or 0,
    helium = helium or 0,
    plasma = plasma or 0,
    duration = duration or 0,
    notes = notes or "",
  }
end

recipes.byTier = {
  [1] = makeRecipe(1, "Overworld", "White Dwarf Matter", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [2] = makeRecipe(2, "Moon", "White Dwarf Matter", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [3] = makeRecipe(3, "Mars", "White Dwarf Matter", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [4] = makeRecipe(4, "Venus", "Black Dwarf Matter", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [5] = makeRecipe(5, "Mercury", "Black Dwarf Matter", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [6] = makeRecipe(6, "Europa", "Universum", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [7] = makeRecipe(7, "Io", "Universum", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [8] = makeRecipe(8, "Vega B", "Universum", 0, 0, 0, 0, "TODO: заполнить по вики"),
  [9] = makeRecipe(9, "Deep Dark", "Energy", 10000000000, 10000000000, 0, 0, "Спецрецепт T9"),
}

recipes.powerMode = makeRecipe(9, "Deep Dark", "Energy", 10000000000, 10000000000, 0, 0, "Power Mode")

function recipes.get(tier)
  return recipes.byTier[tonumber(tier)]
end

function recipes.listTiers()
  local out = {}
  for tier, recipe in pairs(recipes.byTier) do
    out[#out + 1] = { tier = tier, planet = recipe.planet }
  end
  table.sort(out, function(a, b) return a.tier < b.tier end)
  return out
end

function recipes.scale(recipe, overclocks)
  overclocks = math.max(0, math.min(3, tonumber(overclocks) or 0))
  local multiplier = 2 ^ overclocks
  return {
    tier = recipe.tier,
    planet = recipe.planet,
    matter = recipe.matter,
    hydrogen = math.floor((recipe.hydrogen or 0) * multiplier),
    helium = math.floor((recipe.helium or 0) * multiplier),
    plasma = math.floor((recipe.plasma or 0) * multiplier),
    duration = math.max(1, math.floor((recipe.duration or 1) / multiplier)),
    notes = recipe.notes,
    overclocks = overclocks,
    multiplier = multiplier,
  }
end

return recipes
