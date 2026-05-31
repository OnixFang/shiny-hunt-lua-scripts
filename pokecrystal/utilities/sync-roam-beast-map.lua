-- Set a roaming beast's map to your current location (Pokemon Crystal).
-- Helps roaming encounters pass the map check on the route you are grinding.
--
-- Notes:
-- - In Pokemon Crystal, the true roamers are Raikou and Entei.
-- - A third roam struct exists in WRAM; some setups may not use it.
--
-- Run on overworld; keep running if you stay on one route (the game updates roam
-- maps when you change maps).

local DOMAIN = "System Bus"

-- "raikou", "entei", or "suicune"
local TARGET_NAME = "raikou"

-- WRAM from pokecrystal-memory-addresses.sym
local W_MAP_GROUP = 0xDCB5
local W_MAP_NUMBER = 0xDCB6

local GROUP_N_A = 0xFF

local ROAM_TARGETS = {
	raikou = {
		name = "Raikou",
		speciesAddr = 0xDFCF, -- wRoamMon1Species
		mapGroupAddr = 0xDFD1, -- wRoamMon1MapGroup
		mapNumberAddr = 0xDFD2, -- wRoamMon1MapNumber
	},
	entei = {
		name = "Entei",
		speciesAddr = 0xDFD6, -- wRoamMon2Species
		mapGroupAddr = 0xDFD8, -- wRoamMon2MapGroup
		mapNumberAddr = 0xDFD9, -- wRoamMon2MapNumber
	},
	-- Suicune is not normally a roamer in Crystal, but wRoamMon3 exists.
	suicune = {
		name = "Suicune",
		speciesAddr = 0xDFDD, -- wRoamMon3Species
		mapGroupAddr = 0xDFDF, -- wRoamMon3MapGroup
		mapNumberAddr = 0xDFE0, -- wRoamMon3MapNumber
	},
}

local function mapKey(group, mapNumber)
	return group * 256 + mapNumber
end

-- Route labels (same as Gold; map IDs match in Crystal for these routes)
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

local function routeLabel(group, mapNumber)
	return ROUTE_NAMES[mapKey(group, mapNumber)]
		or string.format("group %d map %d", group, mapNumber)
end

local target = ROAM_TARGETS[TARGET_NAME]
if not target then
	error(string.format("Unknown TARGET_NAME %q (use raikou, entei, or suicune)", TARGET_NAME))
end

local function syncBeastToPlayer()
	local playerGroup = memory.read_u8(W_MAP_GROUP, DOMAIN)
	local playerMap = memory.read_u8(W_MAP_NUMBER, DOMAIN)

	memory.write_u8(target.mapGroupAddr, playerGroup, DOMAIN)
	memory.write_u8(target.mapNumberAddr, playerMap, DOMAIN)

	return playerGroup, playerMap
end

local function logSync(playerGroup, playerMap)
	local species = memory.read_u8(target.speciesAddr, DOMAIN)
	if species == 0 then
		console.log(string.format("WARNING: %s inactive (caught/defeated/not initialized?).", target.name))
	elseif memory.read_u8(target.mapGroupAddr, DOMAIN) == GROUP_N_A then
		console.log(string.format("WARNING: %s roam slot is N/A.", target.name))
	else
		console.log(string.format(
			"%s map -> %s (%02X:%02X)",
			target.name,
			routeLabel(playerGroup, playerMap),
			playerGroup,
			playerMap
		))
	end
end

local lastKey = nil

local playerGroup, playerMap = syncBeastToPlayer()
logSync(playerGroup, playerMap)
console.log(string.format("Syncing %s every frame — change TARGET_NAME if needed.", target.name))

while true do
	playerGroup, playerMap = syncBeastToPlayer()

	local key = mapKey(playerGroup, playerMap)
	if key ~= lastKey then
		logSync(playerGroup, playerMap)
		lastKey = key
	end

	gui.text(2, 2, string.format("%s map sync ON", target.name))
	gui.text(2, 14, routeLabel(playerGroup, playerMap))
	gui.text(2, 26, string.format("%02X:%02X", playerGroup, playerMap))
	emu.frameadvance()
end

