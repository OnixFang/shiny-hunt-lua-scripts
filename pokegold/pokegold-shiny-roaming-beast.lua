-- Shiny hunt for roaming Raikou / Entei / Suicune (Pokemon Gold).
-- Option A: savestate on grass at the beast's current route; reload each try.
--
-- Setup:
--   1. Post-Burned Tower save where the target has NEVER been battled (wRoamMonXHP == 0).
--   2. Use the Pokedex area map to reach the route where that beast is now.
--   3. Stand on a grass tile with one clear tile above and below (script walks up/down).
--   4. No Repel, or lead Pokemon level >= 40 (roam level is 40).
--   5. Run this script; slot 2 is overwritten with your starting position.

local DOMAIN = "System Bus"
local SLOT = 2

-- Hunt target: "raikou", "entei", or "suicune"
local TARGET_NAME = "suicune"

-- Up/down cycles per try (each cycle = 1 tile up + 1 tile down; roam rate is low)
local GRASS_CYCLES_PER_TRY = 400

-- Max frames to hold a direction while waiting for one tile of movement
local TILE_WALK_TIMEOUT = 120

-- Frames to advance after reload before walking (RNG tweak, same idea as static script)
local RNG_ADVANCE_FRAMES = 2

-- WRAM (bank 1) — pokegold-memory-addresses.sym
local W_BATTLE_MODE = 0xD116 -- 0=overworld, 1=wild, 2=trainer
local W_BATTLE_TYPE = 0xD119
local W_ENEMYMON_SPECIES = 0xD0EF
local W_ENEMYMON_DVS = 0xD0F5
local W_MAP_GROUP = 0xDA00
local W_MAP_NUMBER = 0xDA01
local W_XCOORD = 0xDA03
local W_YCOORD = 0xDA02

local BATTLETYPE_ROAMING = 5
local GROUP_N_A = 0xFF

local ROAM_TARGETS = {
	raikou = {
		species = 0xF3,
		mapGroup = 0xDD1C,
		mapNumber = 0xDD1D,
		hp = 0xDD1E,
	},
	entei = {
		species = 0xF4,
		mapGroup = 0xDD23,
		mapNumber = 0xDD24,
		hp = 0xDD25,
	},
	suicune = {
		species = 0xF5,
		mapGroup = 0xDD2A,
		mapNumber = 0xDD2B,
		hp = 0xDD2C,
	},
}

local shinyAtkDef = {
	[0x2A] = true,
	[0x3A] = true,
	[0x6A] = true,
	[0x7A] = true,
	[0xAA] = true,
	[0xBA] = true,
	[0xEA] = true,
	[0xFA] = true,
}

local function isShiny(atkdef, spdspc)
	return spdspc == 0xAA and shinyAtkDef[atkdef]
end

local target = ROAM_TARGETS[TARGET_NAME]
if not target then
	error(string.format("Unknown TARGET_NAME %q (use raikou, entei, or suicune)", TARGET_NAME))
end

local function readMap(groupAddr, numberAddr)
	return memory.read_u8(groupAddr, DOMAIN), memory.read_u8(numberAddr, DOMAIN)
end

local function startupChecks()
	local roamMg, roamMn = readMap(target.mapGroup, target.mapNumber)
	local curMg = memory.read_u8(W_MAP_GROUP, DOMAIN)
	local curMn = memory.read_u8(W_MAP_NUMBER, DOMAIN)
	local hp = memory.read_u8(target.hp, DOMAIN)

	if roamMg == GROUP_N_A or roamMn == GROUP_N_A then
		console.log(string.format(
			"WARNING: %s roam data is N/A (caught/defeated?). Hunt may be impossible.",
			TARGET_NAME
		))
	elseif curMg ~= roamMg or curMn ~= roamMn then
		console.log(string.format(
			"WARNING: not on %s's map (beast %02X:%02X, you %02X:%02X). Move before hunting.",
			TARGET_NAME,
			roamMg,
			roamMn,
			curMg,
			curMn
		))
	else
		console.log(string.format("Map OK for %s (%02X:%02X).", TARGET_NAME, roamMg, roamMn))
	end

	if hp ~= 0 then
		console.log(string.format(
			"WARNING: wRoamMon HP=%02X (already fought). DVs are locked; use a save from before first battle.",
			hp
		))
	else
		console.log(string.format("%s HP byte is 0 — first-encounter DV roll OK.", TARGET_NAME))
	end

	console.log(string.format("Walking up/down, %d cycles/try.", GRASS_CYCLES_PER_TRY))
end

local function readPlayerCoords()
	return memory.read_u8(W_XCOORD, DOMAIN), memory.read_u8(W_YCOORD, DOMAIN)
end

local function checkBattleDuringWalk()
	local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
	if battleMode ~= 1 then
		return nil
	end
	local battleType = memory.read_u8(W_BATTLE_TYPE, DOMAIN)
	local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)
	if battleType == BATTLETYPE_ROAMING and species == target.species then
		return "roam"
	end
	return "other_battle"
end

local function walkOneTile(direction)
	local startX, startY = readPlayerCoords()
	local pad = {}
	pad[direction] = true

	for _ = 1, TILE_WALK_TIMEOUT do
		joypad.set(pad)
		emu.frameadvance()

		local outcome = checkBattleDuringWalk()
		if outcome then
			joypad.set({})
			return outcome
		end

		local x, y = readPlayerCoords()
		if direction == "Up" and y == startY - 1 and x == startX then
			break
		elseif direction == "Down" and y == startY + 1 and x == startX then
			break
		end
	end

	joypad.set({})
	return nil
end

local function waitForRoamDVs(timeout)
	local prevAtkdef, prevSpdspc = nil, nil
	while timeout > 0 do
		emu.frameadvance()
		timeout = timeout - 1

		local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
		local battleType = memory.read_u8(W_BATTLE_TYPE, DOMAIN)
		local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)

		if battleMode == 1 and battleType == BATTLETYPE_ROAMING and species == target.species then
			local atkdef = memory.read_u8(W_ENEMYMON_DVS, DOMAIN)
			local spdspc = memory.read_u8(W_ENEMYMON_DVS + 1, DOMAIN)
			local notCleared = atkdef ~= 0 or spdspc ~= 0
			if
				prevAtkdef ~= nil
				and prevAtkdef == atkdef
				and prevSpdspc == spdspc
				and notCleared
			then
				return true, atkdef, spdspc
			end
			prevAtkdef, prevSpdspc = atkdef, spdspc
		else
			prevAtkdef, prevSpdspc = nil, nil
		end
	end
	return false
end

local function grassWalkOneTry()
	for _ = 1, GRASS_CYCLES_PER_TRY do
		local outcome = walkOneTile("Up")
		if outcome then
			return outcome
		end
		outcome = walkOneTile("Down")
		if outcome then
			return outcome
		end
	end

	return "no_battle"
end

startupChecks()
console.log("Saving starting savestate to slot " .. SLOT .. " — position on grass first.")
savestate.saveslot(SLOT)

local tries = 0

while true do
	tries = tries + 1

	savestate.loadslot(SLOT)
	for _ = 1, RNG_ADVANCE_FRAMES do
		emu.frameadvance()
	end
	savestate.saveslot(SLOT)

	local outcome = grassWalkOneTry()

	if outcome == "other_battle" then
		console.log(string.format(
			"Try %d: normal/wrong wild battle — reload and keep walking on %s's route.",
			tries,
			TARGET_NAME
		))
	elseif outcome == "no_battle" then
		console.log(string.format(
			"Try %d: no battle in %d up/down cycles (roam is rare; increase GRASS_CYCLES_PER_TRY).",
			tries,
			GRASS_CYCLES_PER_TRY
		))
	else
		local ready, atkdef, spdspc = waitForRoamDVs(400)
		if not ready then
			console.log(string.format("Try %d: roam battle but DVs never stabilized.", tries))
		elseif isShiny(atkdef, spdspc) then
			console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
			break
		else
			console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
		end
	end
end

client.pause()
