-- Max wild encounter chance on grass steps (Pokemon Gold).
-- Sets wWildEncounterCooldown to 0 and morn/day/nite rates to 255.
--
-- Run on the overworld before grass grinding (e.g. alongside roam shiny hunt).
-- Re-applies every frame so post-battle cooldown does not block the next step.

local DOMAIN = "System Bus"

local W_MORN_ENCOUNTER_RATE = 0xD145
local W_DAY_ENCOUNTER_RATE = 0xD146
local W_NITE_ENCOUNTER_RATE = 0xD147
local W_WILD_ENCOUNTER_COOLDOWN = 0xD179

local MAX_RATE = 255

local function applyEncounterBoost()
	memory.write_u8(W_WILD_ENCOUNTER_COOLDOWN, 0, DOMAIN)
	memory.write_u8(W_MORN_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
	memory.write_u8(W_DAY_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
	memory.write_u8(W_NITE_ENCOUNTER_RATE, MAX_RATE, DOMAIN)
end

applyEncounterBoost()
console.log("Wild encounter boost applied (cooldown=0, rates=255).")
console.log("Leave this script running while you walk in grass; close to stop.")

while true do
	applyEncounterBoost()
	gui.text(2, 2, "Wild encounter boost ON")
	gui.text(2, 14, "cooldown=0  rates=255")
	emu.frameadvance()
end
