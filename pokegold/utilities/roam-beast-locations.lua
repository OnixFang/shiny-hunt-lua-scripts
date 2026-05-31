-- Live display of Raikou / Entei / Suicune roam locations (Pokemon Gold).
-- Use when the Pokedex area page is unavailable (no encounter yet).
--
-- Requires beasts released from Burned Tower (InitRoamMons). Run in BizHawk on overworld.

local DOMAIN = "System Bus"

local W_MAP_GROUP = 0xDA00
local W_MAP_NUMBER = 0xDA01

local GROUP_N_A = 0xFF
local MAP_N_A = 0xFF

local BEASTS = {
	{
		name = "Raikou",
		speciesAddr = 0xDD1A,
		levelAddr = 0xDD1B,
		mapGroupAddr = 0xDD1C,
		mapNumberAddr = 0xDD1D,
		hpAddr = 0xDD1E,
		dvsAddr = 0xDD1F,
	},
	{
		name = "Entei",
		speciesAddr = 0xDD21,
		levelAddr = 0xDD22,
		mapGroupAddr = 0xDD23,
		mapNumberAddr = 0xDD24,
		hpAddr = 0xDD25,
		dvsAddr = 0xDD26,
	},
	{
		name = "Suicune",
		speciesAddr = 0xDD28,
		levelAddr = 0xDD29,
		mapGroupAddr = 0xDD2A,
		mapNumberAddr = 0xDD2B,
		hpAddr = 0xDD2C,
		dvsAddr = 0xDD2D,
	},
}

local function mapKey(group, mapNumber)
	return group * 256 + mapNumber
end

-- Johto routes beasts can roam on (group, map) -> display name
local ROUTE_NAMES = {
	[mapKey(24, 3)] = "Route 29",
	[mapKey(26, 1)] = "Route 30",
	[mapKey(26, 2)] = "Route 31",
	[mapKey(10, 1)] = "Route 32",
	[mapKey(8, 6)] = "Route 33",
	[mapKey(11, 1)] = "Route 34",
	[mapKey(10, 2)] = "Route 35",
	[mapKey(10, 3)] = "Route 36",
	[mapKey(10, 4)] = "Route 37",
	[mapKey(1, 12)] = "Route 38",
	[mapKey(1, 13)] = "Route 39",
	[mapKey(1, 5)] = "Route 42",
	[mapKey(9, 5)] = "Route 43",
	[mapKey(1, 6)] = "Route 44",
	[mapKey(5, 8)] = "Route 45",
	[mapKey(5, 9)] = "Route 46",
}

-- From data/wild/roammon_maps.asm (possible next routes after map change)
local ROAM_NEIGHBORS = {
	[mapKey(24, 3)] = { "Route 30", "Route 46" },
	[mapKey(26, 1)] = { "Route 29", "Route 31" },
	[mapKey(26, 2)] = { "Route 30", "Route 32", "Route 36" },
	[mapKey(10, 1)] = { "Route 36", "Route 31", "Route 33" },
	[mapKey(8, 6)] = { "Route 32", "Route 34" },
	[mapKey(11, 1)] = { "Route 33", "Route 35" },
	[mapKey(10, 2)] = { "Route 34", "Route 36" },
	[mapKey(10, 3)] = { "Route 35", "Route 31", "Route 32", "Route 37" },
	[mapKey(10, 4)] = { "Route 36", "Route 38", "Route 42" },
	[mapKey(1, 12)] = { "Route 37", "Route 39", "Route 42" },
	[mapKey(1, 13)] = { "Route 38" },
	[mapKey(1, 5)] = { "Route 43", "Route 44", "Route 37", "Route 38" },
	[mapKey(9, 5)] = { "Route 42", "Route 44" },
	[mapKey(1, 6)] = { "Route 42", "Route 43", "Route 45" },
	[mapKey(5, 8)] = { "Route 44", "Route 46" },
	[mapKey(5, 9)] = { "Route 45", "Route 29" },
}

local function resolveRouteName(group, mapNumber)
	if group == GROUP_N_A or mapNumber == MAP_N_A then
		return nil, "gone (caught or defeated)"
	end
	local key = mapKey(group, mapNumber)
	local name = ROUTE_NAMES[key]
	if name then
		return name, nil
	end
	return nil, string.format("unknown route (group %d, map %d)", group, mapNumber)
end

local function neighborsText(group, mapNumber)
	local list = ROAM_NEIGHBORS[mapKey(group, mapNumber)]
	if not list then
		return ""
	end
	return "  next: " .. table.concat(list, ", ")
end

local function readBeastState(beast)
	local species = memory.read_u8(beast.speciesAddr, DOMAIN)
	local level = memory.read_u8(beast.levelAddr, DOMAIN)
	local mapGroup = memory.read_u8(beast.mapGroupAddr, DOMAIN)
	local mapNumber = memory.read_u8(beast.mapNumberAddr, DOMAIN)
	local hp = memory.read_u8(beast.hpAddr, DOMAIN)
	local atkdef = memory.read_u8(beast.dvsAddr, DOMAIN)
	local spdspc = memory.read_u8(beast.dvsAddr + 1, DOMAIN)

	local routeName, statusNote = resolveRouteName(mapGroup, mapNumber)
	local status
	if species == 0 then
		status = "inactive"
	elseif mapGroup == GROUP_N_A then
		status = "gone (caught or defeated)"
	else
		status = routeName or statusNote
	end

	local dvNote = ""
	if hp ~= 0 then
		dvNote = string.format(" DVs=%02X/%02X (locked)", atkdef, spdspc)
	elseif species ~= 0 and mapGroup ~= GROUP_N_A then
		dvNote = " DVs=not set yet"
	end

	return {
		species = species,
		level = level,
		mapGroup = mapGroup,
		mapNumber = mapNumber,
		hp = hp,
		status = status,
		routeName = routeName,
		dvNote = dvNote,
		neighbors = (routeName and neighborsText(mapGroup, mapNumber)) or "",
	}
end

local function formatLine(beast, state, playerHere)
	local here = playerHere and " <<< YOU ARE HERE" or ""
	return string.format(
		"%s: %s (Lv%d, HP=%02X)%s%s",
		beast.name,
		state.status,
		state.level,
		state.hp,
		state.dvNote,
		here
	)
end

local lastSnapshot = nil

local function logIfChanged(beasts, playerGroup, playerMap)
	local lines = {}
	for i, beast in ipairs(BEASTS) do
		local state = beasts[i]
		local playerHere = state.routeName
			and state.mapGroup == playerGroup
			and state.mapNumber == playerMap
		lines[i] = formatLine(beast, state, playerHere) .. state.neighbors
	end
	local snapshot = table.concat(lines, "|") .. "|" .. playerGroup .. ":" .. playerMap
	if snapshot == lastSnapshot then
		return
	end
	lastSnapshot = snapshot

	local playerName = ROUTE_NAMES[mapKey(playerGroup, playerMap)]
	console.log("--- Roam beast locations ---")
	console.log(string.format(
		"Your map: %s (group %d, map %d)",
		playerName or "?",
		playerGroup,
		playerMap
	))
	for i, beast in ipairs(BEASTS) do
		console.log(lines[i])
	end
end

console.log("Roam beast location monitor started (console updates on change).")

while true do
	local playerGroup = memory.read_u8(W_MAP_GROUP, DOMAIN)
	local playerMap = memory.read_u8(W_MAP_NUMBER, DOMAIN)

	local beasts = {}
	for i, beast in ipairs(BEASTS) do
		beasts[i] = readBeastState(beast)
	end

	logIfChanged(beasts, playerGroup, playerMap)

	gui.text(2, 2, "Roam locations (Gold):")
	local y = 14
	for i, beast in ipairs(BEASTS) do
		local state = beasts[i]
		local playerHere = state.routeName
			and state.mapGroup == playerGroup
			and state.mapNumber == playerMap
		gui.text(2, y, formatLine(beast, state, playerHere))
		y = y + 12
		if state.neighbors ~= "" then
			gui.text(2, y, state.neighbors)
			y = y + 12
		end
	end

	local playerName = ROUTE_NAMES[mapKey(playerGroup, playerMap)]
	gui.text(2, y + 4, string.format("You: %s (%d:%d)", playerName or "?", playerGroup, playerMap))

	emu.frameadvance()
end
