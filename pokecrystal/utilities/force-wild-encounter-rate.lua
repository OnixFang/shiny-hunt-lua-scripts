-- Max wild encounter chance on grass steps (Pokemon Crystal).
-- Sets wWildEncounterCooldown to 0 and encounter rates to 255.
--
-- Run on the overworld before grass grinding (e.g. alongside roam shiny hunt).
-- Re-applies every frame so post-battle cooldown does not block the next step.

local DOMAIN = "System Bus"

-- WRAM from pokecrystal-memory-addresses.sym (bank 01)
local W_MORN_ENCOUNTER_RATE = 0xD25A
local W_DAY_ENCOUNTER_RATE = 0xD25B
local W_NITE_ENCOUNTER_RATE = 0xD25C
local W_WATER_ENCOUNTER_RATE = 0xD25D
local W_WILD_ENCOUNTER_COOLDOWN = 0xD452

local MAX_RATE = 255

local function applyEncounterBoost()
	memory.write_u8(W_WILD_ENCOUNTER_COOLDOWN, 0, DOMAIN)
	memory.write_u8(W_MORN_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
	memory.write_u8(W_DAY_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
	memory.write_u8(W_NITE_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
	memory.write_u8(W_WATER_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
end

applyEncounterBoost()
console.log("Wild encounter boost applied (cooldown=0, rates=255).")
console.log("Leave this script running while you walk; close to stop.")

while true do
	applyEncounterBoost()
	gui.text(2, 2, "Wild encounter boost ON")
	gui.text(2, 14, "cooldown=0  rates=255")
	emu.frameadvance()
end

