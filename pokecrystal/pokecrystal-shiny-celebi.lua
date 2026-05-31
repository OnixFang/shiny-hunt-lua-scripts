-- Shiny hunt for Celebi at the Ilex Forest shrine (Pokemon Crystal).
--
-- Setup:
--   1. Stand in front of the shrine with the GS Ball in your bag and EVENT_FOREST_IS_RESTLESS set.
--   2. Save a BizHawk savestate (slot 2 is overwritten by this script).
--   3. Run this script; it will attempt to trigger the shrine event, enter the battle,
--      read Celebi's DVs, and pause when shiny.
--
-- Notes:
-- - This script does NOT try to catch Celebi; it only checks shininess.
-- - If your dialog timing differs (text speed, emulator lag), increase START_TIMEOUT.

local DOMAIN = "System Bus"
local SLOT = 2

-- Frames to advance after reload before triggering (RNG tweak)
local RNG_ADVANCE_FRAMES = 2

-- How long to wait for the shrine cutscene + battle to start
local START_TIMEOUT = 2400

-- How long to wait for enemy struct + DVs to stabilize after battle starts
local DV_TIMEOUT = 900

-- WRAM (bank 1) — pokecrystal-memory-addresses.sym
local W_BATTLE_MODE = 0xD22D -- 0=overworld, 1=wild, 2=trainer (banked)
local W_ENEMYMON_SPECIES = 0xD206
local W_ENEMYMON_DVS = 0xD20C

local TARGET_SPECIES = 0xFB -- CELEBI (internal species id)

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

local function pressA(frames)
	joypad.set({})
	for _ = 1, frames do
		joypad.set({ A = true })
		emu.frameadvance()
	end
	joypad.set({})
end

local function mashAUntilBattleOrTimeout()
	local timeout = START_TIMEOUT
	local mashCounter = 0

	while timeout > 0 do
		emu.frameadvance()
		timeout = timeout - 1
		mashCounter = mashCounter + 1

		-- Mash A periodically to: interact -> accept text -> answer yes/no -> advance cutscene.
		if mashCounter % 20 == 0 then
			pressA(2)
		end

		local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
		if battleMode == 1 then
			local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)
			if species == TARGET_SPECIES then
				return true
			end
		end
	end

	return false
end

local function waitForCelebiDVs(timeout)
	local prevAtkdef, prevSpdspc = nil, nil

	while timeout > 0 do
		emu.frameadvance()
		timeout = timeout - 1

		local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
		local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)

		if battleMode == 1 and species == TARGET_SPECIES then
			local atkdef = memory.read_u8(W_ENEMYMON_DVS, DOMAIN)
			local spdspc = memory.read_u8(W_ENEMYMON_DVS + 1, DOMAIN)
			local notCleared = atkdef ~= 0 or spdspc ~= 0

			if prevAtkdef ~= nil and prevAtkdef == atkdef and prevSpdspc == spdspc and notCleared then
				return true, atkdef, spdspc
			end

			prevAtkdef, prevSpdspc = atkdef, spdspc
		else
			prevAtkdef, prevSpdspc = nil, nil
		end
	end

	return false
end

console.log("pokecrystal-shiny-celebi: saving baseline savestate to slot " .. SLOT)
savestate.saveslot(SLOT)

local tries = 0

while true do
	tries = tries + 1

	savestate.loadslot(SLOT)
	for _ = 1, RNG_ADVANCE_FRAMES do
		emu.frameadvance()
	end
	savestate.saveslot(SLOT)

	local started = mashAUntilBattleOrTimeout()
	if not started then
		console.log(string.format("Try %d: timed out waiting for Celebi battle to start (increase START_TIMEOUT?)", tries))
	else
		local ready, atkdef, spdspc = waitForCelebiDVs(DV_TIMEOUT)
		if not ready then
			console.log(string.format("Try %d: battle started but DVs never stabilized (increase DV_TIMEOUT?)", tries))
		elseif isShiny(atkdef, spdspc) then
			console.log(string.format("Shiny Celebi! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
			break
		else
			console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
		end
	end
end

client.pause()

