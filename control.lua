-------------------------------------------------------------------------------
-- CONFIGURATION
--

-- Can be either entity name or type.
-- Simply adding new entities to the list does not make them work.
-- But adding new entities through other mods to the categories enabled below should work.
local CONFIG_ENABLE = {
	-- Types
	["ammo-turret"] = true, -- rail-turret is also an ammo-turret
	car = true,
	locomotive = true,
	["artillery-turret"] = true,
	["artillery-wagon"] = true,
	["spider-vehicle"] = true,

	-- Specific items
	["burner-inserter"] = true,
	["stone-furnace"] = true,
	["steel-furnace"] = true,
	["burner-mining-drill"] = true,
	boiler = true,
}

-- These entity types or names are ignored whether specified in CONFIG_ENABLE or not.
local CONFIG_DISABLE = {
	["fluid-turret"] = true,
	["electric-turret"] = true,
	["combat-robot"] = true,
}

-- key: prototype entity name
-- value: map of gun item name : ammo category
-- - OR -
-- value: map of ammo category : ammo category
-- This could probably in practice be simplified to a map of entityName : {ammoCategory, ...}
-- but since ammo_categories is ALWAYS a table, we'll just futureproof it
local weapons = {}

-------------------------------------------------------------------------------
-- CACHE TABLES
--

local itemStackCache
do
	local cache = {}
	itemStackCache = setmetatable({}, {
		__index = cache,
		__newindex = function(_, key, value)
			if cache[key] then
				cache[key].count = value
			else
				cache[key] = { name = key, count = value, }
			end
		end,
	})
end

-------------------------------------------------------------------------------
-- SETTINGS
--

local getStackSize, getAmmoCategories, getSortedFuels
do
	-------------------------------------------------------------------------------
	-- AMMUNITION
	--

	-- Map: ammo category name : array of ammo prototype name
	---@type table
	local ammoCategories

	-- map: player index : ammoCategories
	local ammoCategoriesPerPlayer = {}

	local buildAmmoData
	do
		local ammoOrder = nil

		---@cast ammoOrder table
		local function sortByOrder(a, b) return ammoOrder[a] > ammoOrder[b] end

		buildAmmoData = function()
			-- Just so we can ignore all the weird ammo types in the prototypes
			local foundAmmoCategories = {}

			ammoOrder = {}
			ammoCategories = {}

			for name, ent in pairs(prototypes.entity) do
				if not CONFIG_DISABLE[ent.type] and not CONFIG_DISABLE[name] and (CONFIG_ENABLE[name] or CONFIG_ENABLE[ent.type]) then
					-- If the entity has indexed_guns, we have our answer right there
					if ent.indexed_guns and #ent.indexed_guns > 0 then
						for _, p in next, ent.indexed_guns do
							if prototypes.item[p.name] then
								local params = prototypes.item[p.name].attack_parameters
								if params and params.ammo_categories then
									-- params.ammo_categories is always a table at runtime apparently, even if there's 1
									for _, cat in next, params.ammo_categories do
										foundAmmoCategories[cat] = true
										if not weapons[name] then weapons[name] = {} end
										if not weapons[name][p.name] then weapons[name][p.name] = {} end
										table.insert(weapons[name][p.name], cat)
									end
								end
							end
						end
					elseif ent.attack_parameters then
						if ent.attack_parameters.ammo_categories then
							-- same here, params.ammo_categories is always a table at runtime apparently, even if there's 1
							for _, cat in next, ent.attack_parameters.ammo_categories do
								foundAmmoCategories[cat] = true
								if not weapons[name] then weapons[name] = {} end
								if not weapons[name][name] then weapons[name][name] = {} end
								table.insert(weapons[name][name], cat)
							end
						end
					end
				end
			end

			for name, it in pairs(prototypes.item) do
				if it.type == "ammo" then
					if it.ammo_category and it.ammo_category.name and foundAmmoCategories[it.ammo_category.name] then
						local cat = it.ammo_category.name
						if foundAmmoCategories[cat] then
							if not ammoCategories[cat] then ammoCategories[cat] = {} end
							ammoOrder[name] = it.order
							table.insert(ammoCategories[cat], name)
						end
					end
				end
			end

			for _, ammos in pairs(ammoCategories) do
				table.sort(ammos, sortByOrder)
			end

			ammoOrder = nil
		end
	end

	-------------------------------------------------------------------------------
	-- FUEL
	--

	-- Sorted array of fuel item names by real fuel value (fuel_value * stack_size)
	local sortedFuels = nil
	-- map of player index : sortedFuels
	local sortedFuelsPerPlayer = {}

	local buildFuelTable
	do
		-- Map of fuel names to real fuel values, multiplied by stack size
		local fuelValues = nil

		---@cast fuelValues table
		local function sortFuels(a, b) return fuelValues[a] > fuelValues[b] end
		buildFuelTable = function()
			-- Dump previous tables for garbage collection
			sortedFuels = {}
			fuelValues = {}

			for name, item in pairs(prototypes.item) do
				if item.fuel_category and item.fuel_category == "chemical" and item.fuel_value and item.fuel_value > 0 then
					-- Dang these values are crazy, up in the trillions
					local realScore = (item.stack_size * item.fuel_value) / 10000000
					fuelValues[name] = realScore
					sortedFuels[#sortedFuels + 1] = name
				end
			end
			table.sort(sortedFuels, sortFuels)
			fuelValues = nil
		end
	end

	local FILTER_CSV = "([%w%-%_]+)"
	local FILTER_LEADING_SPACE = "^%s*()"
	local FILTER_TRAILING_SPACE = ".*%S"
	local EMPTY_STRING = ""

	local function trim(s)
		local from = s:match(FILTER_LEADING_SPACE)
		return from > #s and EMPTY_STRING or s:match(FILTER_TRAILING_SPACE, from)
	end

	-- ini == best format ever
	local iniFuelStackSize = "folk-fill-fuel-stack-size"
	local iniAmmoStackSize = "folk-fill-ammo-stack-size"
	local iniIgnoreAmmo = "folk-fill-ammo-ignore"
	local iniPreferAmmo = "folk-fill-ammo-prefer"
	local iniIgnoreFuel = "folk-fill-fuel-ignore"
	local iniPreferFuel = "folk-fill-fuel-prefer"

	local map = {
		[iniFuelStackSize] = 100,
		[iniAmmoStackSize] = 10,
		[iniIgnoreAmmo] = "capture-robot-rocket, atomic-bomb",
		[iniPreferAmmo] = "",
		[iniIgnoreFuel] = "",
		[iniPreferFuel] = "",
	}

	local ini = {}
	local stackSizes = {}

	local function getSetting(p, setting)
		if not ini[p] then ini[p] = {} end
		if type(ini[p][setting]) == "nil" then
			ini[p][setting] = settings.get_player_settings(game.players[p])[setting]
				.value
		end
		return ini[p][setting]
	end

	local meta = {
		__index = function(self, item)
			local ret = nil
			if type(item) ~= "string" then return 20 end
			local p = prototypes.item[item]
			if type(p) == "userdata" then
				local max = type(p.stack_size) ~= "nil" and tonumber(p.stack_size) or 50
				if max > 1 then
					local percent
					if p.fuel_category then
						percent = getSetting(self.player_index, iniFuelStackSize)
					else
						percent = getSetting(self.player_index, iniAmmoStackSize)
					end
					if type(percent) ~= "number" then percent = 75 end
					ret = math.max(1, math.ceil(max * (percent / 100)))
				else
					ret = 1
				end
			end
			if type(ret) ~= "number" then return 10 end
			rawset(self, item, ret)
			return ret
		end,
	}

	local function parseSet(p, setting)
		local tokens = trim(getSetting(p, setting) or EMPTY_STRING)
		local ret = {}
		for token in tokens:gmatch(FILTER_CSV) do
			ret[token] = true
		end
		return ret
	end

	local function parseList(p, setting)
		local tokens = trim(getSetting(p, setting) or EMPTY_STRING)
		local ret = {}
		for token in tokens:gmatch(FILTER_CSV) do
			table.insert(ret, token)
		end
		return ret
	end

	local function updateAmmo(p)
		if not ammoCategories then buildAmmoData() end
		local ignoredAmmo = parseSet(p, iniIgnoreAmmo)

		-- Ignore ammo
		ammoCategoriesPerPlayer[p] = {}
		for category, ammos in pairs(ammoCategories) do
			ammoCategoriesPerPlayer[p][category] = { table.unpack(ammos), }
		end
		for _, ammos in pairs(ammoCategoriesPerPlayer[p]) do
			for i = #ammos, 1, -1 do
				if ignoredAmmo[ammos[i]] then
					table.remove(ammos, i)
				end
			end
		end

		local preferredAmmo = parseList(p, iniPreferAmmo)
		-- Preferred ammo
		for _, ammos in pairs(ammoCategoriesPerPlayer[p]) do
			local weights = {}
			local max = #ammos + 1

			for i = 1, #ammos do
				weights[ammos[i]] = (max - i)
			end
			for i = #preferredAmmo, 1, -1 do
				weights[preferredAmmo[i]] = (i * 100) + max
			end

			table.sort(ammos, function(a, b)
				return weights[a] > weights[b]
			end)
		end
	end

	local function updateFuel(p)
		if not sortedFuels then buildFuelTable() end

		local ignoredFuel = parseSet(p, iniIgnoreFuel)
		---@cast sortedFuels table
		sortedFuelsPerPlayer[p] = { table.unpack(sortedFuels), }
		for i = #sortedFuelsPerPlayer[p], 1, -1 do
			if ignoredFuel[sortedFuelsPerPlayer[p][i]] then
				table.remove(sortedFuelsPerPlayer[p], i)
			end
		end

		local preferredFuel = parseList(p, iniPreferFuel)
		-- most preferred first
		for i = 1, #preferredFuel do
			for j = #sortedFuelsPerPlayer[p], 1, -1 do
				if sortedFuelsPerPlayer[p][j] == preferredFuel[i] then
					table.remove(sortedFuelsPerPlayer[p], j)
				end
			end
			table.insert(sortedFuelsPerPlayer[p], i, preferredFuel[i])
		end
	end

	local function updateStackSizes(p)
		stackSizes[p] = setmetatable({ player_index = p, }, meta)
	end

	getStackSize = function(player, item)
		if not stackSizes[player.index] then updateStackSizes(player.index) end
		return stackSizes[player.index][item]
	end
	getAmmoCategories = function(player)
		if not ammoCategoriesPerPlayer[player.index] then updateAmmo(player.index) end
		return ammoCategoriesPerPlayer[player.index]
	end
	getSortedFuels = function(player)
		if not sortedFuelsPerPlayer[player.index] then updateFuel(player.index) end
		return sortedFuelsPerPlayer[player.index]
	end

	script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
		local s = event.setting
		if not s or not map[s] then return end

		local p = game.players[event.player_index]
		if not p or not p.valid then return end

		if not ini[p.index] then ini[p.index] = {} end

		local value = settings.get_player_settings(p)[s].value
		ini[p.index][s] = value

		if s == iniAmmoStackSize or s == iniFuelStackSize then
			updateStackSizes(p.index)
		elseif s == iniIgnoreFuel or s == iniPreferFuel then
			updateFuel(p.index)
		elseif s == iniIgnoreAmmo or s == iniPreferAmmo then
			updateAmmo(p.index)
		end
	end)
end

-------------------------------------------------------------------------------
-- AMMUNITION INSERTERTS FOR CARS/TURRETS
--

-- Turret ammo slots do not support filters
-- So we basically just have to try everything and see what works
local function insertAmmo(entName, player, inv)
	local fromInv = player.get_inventory(defines.inventory.character_main)
	if not fromInv or not fromInv.valid or fromInv.is_empty() then return end

	local forbidden = {}
	local cats = getAmmoCategories(player)

	for _, weapon in pairs(weapons[entName]) do
		for _, category in next, weapon do -- There is only ever really one category in each weapon in vanilla at least
			for _, ammo in next, cats[category] do
				if not forbidden[ammo] then
					-- XXX how should we handle quality? every get_item_count
					local count = fromInv.get_item_count(ammo)

					-- Never try to insert the same ammo twice in the same entity.
					forbidden[ammo] = true

					if count > 0 then
						local toInsert = getStackSize(player, ammo)

						-- Do we have enough items on us to insert?
						if count < toInsert then toInsert = math.ceil(count / 4) end

						itemStackCache[ammo] = toInsert
						local inserted = inv.insert(itemStackCache[ammo])
						if inserted and inserted > 0 then
							itemStackCache[ammo] = inserted
							fromInv.remove(itemStackCache[ammo])
						end

						-- Get to next slot
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- FUEL INSERTERS FOR TRAINS/CARS
--

local insertFuel
do
	local function insert(fuel, to, from)
		local inserted = to.insert(itemStackCache[fuel])
		if inserted and inserted > 0 then -- Just in case this fuel type doesnt work or something
			itemStackCache[fuel] = inserted
			from.remove(itemStackCache[fuel])
			return true
		end
	end
	insertFuel = function(entity, player, invFuel)
		local fromInv = player.get_inventory(defines.inventory.character_main)
		if not fromInv or not fromInv.valid or fromInv.is_empty() then return end

		-- Haxx; if we are not passed an invFuel argument, we set it to the entity
		-- itself (which accepts .insert)
		if not invFuel then invFuel = entity end -- .get_inventory(defines.inventory.fuel)

		local fuels = getSortedFuels(player)
		for _, fuel in next, fuels do
			-- XXX how should we handle quality? every get_item_count
			local count = fromInv.get_item_count(fuel)
			if count > 0 then
				local should = getStackSize(player, fuel)

				-- If we have exactly or less than the configured amount left in the inventory, then dont use it all
				if count <= should then
					should = math.ceil(count / 2)
				end

				if should > 0 then
					itemStackCache[fuel] = should
					if insert(fuel, invFuel, fromInv) then break end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- EVENT HANDLERS
--
do
	-- For entities where we probably want to just look at every type that
	-- is placed
	local typeHandlers = {}

	-- For entities where we only want to look at specific ones, and not the
	-- whole category of entity types
	-- ZZZ Obviously this does not scale to modded items
	local nameHandlers = {}

	typeHandlers["ammo-turret"] = function(entity, player)
		local invAmmo = entity.get_inventory(defines.inventory.turret_ammo)
		if invAmmo and invAmmo.valid and invAmmo.is_empty() then
			insertAmmo(entity.name, player, invAmmo)
		end
	end

	typeHandlers["artillery-turret"] = function(entity, player)
		local invAmmo = entity.get_inventory(defines.inventory.artillery_turret_ammo)
		if invAmmo and invAmmo.valid and invAmmo.is_empty() then
			insertAmmo(entity.name, player, invAmmo)
		end
	end

	typeHandlers["artillery-wagon"] = function(entity, player)
		local invAmmo = entity.get_inventory(defines.inventory.artillery_wagon_ammo)
		if invAmmo and invAmmo.valid and invAmmo.is_empty() then
			insertAmmo(entity.name, player, invAmmo)
		end
	end

	typeHandlers["spider-vehicle"] = function(entity, player)
		local invAmmo = entity.get_inventory(defines.inventory.spider_ammo)
		if invAmmo and invAmmo.valid and invAmmo.is_empty() then
			insertAmmo(entity.name, player, invAmmo)
		end
	end

	typeHandlers.car = function(entity, player)
		local invAmmo = entity.get_inventory(defines.inventory.car_ammo)
		if invAmmo and invAmmo.valid and invAmmo.is_empty() then
			insertAmmo(entity.name, player, invAmmo)
		end

		local invFuel = entity.get_inventory(defines.inventory.fuel)
		if invFuel and invFuel.valid and invFuel.is_empty() then
			insertFuel(entity, player, invFuel)
		end
	end

	typeHandlers.locomotive = insertFuel
	nameHandlers["stone-furnace"] = insertFuel
	nameHandlers["steel-furnace"] = insertFuel
	nameHandlers["burner-inserter"] = insertFuel
	nameHandlers["burner-mining-drill"] = insertFuel
	nameHandlers.boiler = insertFuel

	local function onBuildEntity(e)
		local entity = e.entity
		if not entity or not entity.valid or (not CONFIG_ENABLE[entity.type] and not CONFIG_ENABLE[entity.name]) then return end

		-- Just in case someone inserts an unknown type into CONFIG_ENABLE
		if typeHandlers[entity.type] then
			typeHandlers[entity.type](entity, game.players[e.player_index])
		elseif nameHandlers[entity.name] then
			nameHandlers[entity.name](entity, game.players[e.player_index])
		end
	end

	script.on_event(defines.events.on_built_entity, onBuildEntity)
end


-- script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
-- 	local p = game.players[event.player_index]
-- 	if not p or not p.cursor_stack or not p.cursor_stack.valid_for_read then
-- 		print("wtf")
-- 		return
-- 	end
-- 	print(p.cursor_stack.type .. "/" .. p.cursor_stack.name)
-- 	if p.cursor_stack.is_blueprint_setup() then
-- 		print"yes"
-- 	end
-- 	if p.cursor_stack.label then print(p.cursor_stack.label) end
-- end)
