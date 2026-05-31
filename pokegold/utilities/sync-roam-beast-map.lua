-- Set a roaming beast's map to your current location (Pokemon Gold).
-- Helps roam encounters pass the map check on the route you are grinding.
--
-- Set TARGET_NAME to the beast you are hunting. Run on overworld; keep running
-- if you stay on one route (the game resets roam maps when you change maps).

local DOMAIN = "System Bus"

-- "raikou", "entei", or "suicune"
local TARGET_NAME = "suicune"

local W_MAP_GROUP = 0xDA00
local W_MAP_NUMBER = 0xDA01

local GROUP_N_A = 0xFF

local ROAM_TARGETS = {
	raikou = {
		name = "Raikou",
		speciesAddr = 0xDD1A,
		mapGroupAddr = 0xDD1C,
		mapNumberAddr = 0xDD1D,
	},
	entei = {
		name = "Entei",
		speciesAddr = 0xDD21,
		mapGroupAddr = 0xDD23,
		mapNumberAddr = 0xDD24,
	},
	suicune = {
		name = "Suicune",
		speciesAddr = 0xDD28,
		mapGroupAddr = 0xDD2A,
		mapNumberAddr = 0xDD2B,
	},
}

local function mapKey(group, mapNumber)
	return group * 256 + mapNumber
end

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
		console.log(string.format("WARNING: %s inactive (caught/defeated?).", target.name))
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
