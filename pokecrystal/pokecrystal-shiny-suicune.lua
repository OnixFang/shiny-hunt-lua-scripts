-- Shiny hunt for scripted Suicune at Tin Tower 1F (Pokemon Crystal).
--
-- Setup:
--   1. Post-Elite Four save where Suicune has NEVER been battled (beasts still on 1F).
--   2. Clear Bell / Wise Trio passage obtained; Tin Tower accessible.
--   3. Enter Tin Tower 1F and stand near the bottom (y=14–15) facing up, BEFORE the
--      cutscene starts. Create a savestate (slot 2 is overwritten by this script).
--   4. wTinTower1FSceneID must be 0 (SCENE_TINTOWER1F_SUICUNE_BATTLE). If you already
--      saw the cutscene once, reload an earlier save — the scene switches to NOOP.
--   5. You cannot run from this battle; the script reloads after each non-shiny roll.
--
-- Each try: reload, advance RNG, walk up to start the scene, wait through Raikou/Entei/
-- Suicune animations, read DVs as soon as the battle starts, then reload if not shiny.

local DOMAIN = "System Bus"
local SLOT = 2

-- Frames to advance after reload before triggering (RNG tweak, same idea as other scripts)
local RNG_ADVANCE_FRAMES = 2

-- Max frames to hold Up while waiting for the scene to latch (scripted movement or tile step)
local TRIGGER_TIMEOUT = 180

-- Max frames to wait for Suicune battle + stable DVs (long cutscene before battle)
local BATTLE_TIMEOUT = 9000

-- WRAM (bank 1) — pokecrystal-memory-addresses.sym
local W_BATTLE_MODE = 0xD22D -- 0=overworld, 1=wild, 2=trainer
local W_BATTLE_TYPE = 0xD230
local W_ENEMYMON_SPECIES = 0xD206
local W_ENEMYMON_DVS = 0xD20C
local W_MAP_GROUP = 0xDCB5
local W_MAP_NUMBER = 0xDCB6
local W_YCOORD = 0xDCB7
local W_SCRIPT_RUNNING = 0xD438
local W_TINTOWER1F_SCENE_ID = 0xD9A6

local MAP_GROUP_TIN_TOWER_1F = 0x0A
local MAP_NUMBER_TIN_TOWER_1F = 0x09

local SCENE_TINTOWER1F_SUICUNE_BATTLE = 0

local TARGET_SPECIES = 0xF5 -- SUICUNE
local BATTLETYPE_SUICUNE = 12
local WILD_BATTLE = 1

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

local function isSuicuneBattle()
	local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
	local battleType = memory.read_u8(W_BATTLE_TYPE, DOMAIN)
	local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)
	return battleMode == WILD_BATTLE
		and battleType == BATTLETYPE_SUICUNE
		and species == TARGET_SPECIES
end

local function startupChecks()
	local mapGroup = memory.read_u8(W_MAP_GROUP, DOMAIN)
	local mapNumber = memory.read_u8(W_MAP_NUMBER, DOMAIN)
	local sceneId = memory.read_u8(W_TINTOWER1F_SCENE_ID, DOMAIN)

	if mapGroup ~= MAP_GROUP_TIN_TOWER_1F or mapNumber ~= MAP_NUMBER_TIN_TOWER_1F then
		console.log(string.format(
			"WARNING: not on Tin Tower 1F (you %02X:%02X, expected %02X:%02X).",
			mapGroup,
			mapNumber,
			MAP_GROUP_TIN_TOWER_1F,
			MAP_NUMBER_TIN_TOWER_1F
		))
	else
		console.log("Map OK: Tin Tower 1F.")
	end

	if sceneId ~= SCENE_TINTOWER1F_SUICUNE_BATTLE then
		console.log(string.format(
			"WARNING: wTinTower1FSceneID=%d (need %d). Use a save from before the Suicune cutscene.",
			sceneId,
			SCENE_TINTOWER1F_SUICUNE_BATTLE
		))
	else
		console.log("Scene ID OK — Suicune battle scene is armed.")
	end

	console.log("Hold position at tower bottom facing up, then let the script walk Up to trigger.")
end

local function triggerSuicuneScene()
	local startY = memory.read_u8(W_YCOORD, DOMAIN)

	for _ = 1, TRIGGER_TIMEOUT do
		if isSuicuneBattle() then
			joypad.set({})
			return "battle"
		end

		local scriptRunning = memory.read_u8(W_SCRIPT_RUNNING, DOMAIN)
		if scriptRunning ~= 0 then
			joypad.set({})
			return "scene"
		end

		local y = memory.read_u8(W_YCOORD, DOMAIN)
		if y < startY then
			joypad.set({})
			return "moved"
		end

		joypad.set({ Up = true })
		emu.frameadvance()
	end

	joypad.set({})
	return "timeout"
end

local function waitForSuicuneDVs(timeout)
	local prevAtkdef, prevSpdspc = nil, nil

	while timeout > 0 do
		joypad.set({})
		emu.frameadvance()
		timeout = timeout - 1

		if isSuicuneBattle() then
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

startupChecks()
console.log("Saving starting savestate to slot " .. SLOT .. ".")
savestate.saveslot(SLOT)

local tries = 0

while true do
	tries = tries + 1

	savestate.loadslot(SLOT)
	for _ = 1, RNG_ADVANCE_FRAMES do
		emu.frameadvance()
	end
	savestate.saveslot(SLOT)

	local trigger = triggerSuicuneScene()
	if trigger == "timeout" then
		console.log(string.format(
			"Try %d: scene never started (check position, facing, or wTinTower1FSceneID).",
			tries
		))
	else
		local ready, atkdef, spdspc = waitForSuicuneDVs(BATTLE_TIMEOUT)
		if not ready then
			console.log(string.format(
				"Try %d: cutscene/battle timed out after trigger=%s — increase BATTLE_TIMEOUT?",
				tries,
				trigger
			))
		elseif isShiny(atkdef, spdspc) then
			console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
			break
		else
			console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
		end
	end
end

client.pause()
