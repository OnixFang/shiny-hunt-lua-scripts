local DOMAIN = "System Bus"
local SLOT = 2

-- WRAM addresses (pokegold)
local W_EGGMON_SPECIES = 0xDCC6
local W_EGGMON_DVS = 0xDCDB -- first byte, second byte at +1

-- Shiny DV byte for attack and defense
local shinyAtkDef = {
	[0x2A] = true,
	[0x3A] = true,
	[0x6A] = true,
	[0x7A] = true,
	[0xAA] = true,
	[0xBA] = true,
	[0xEA] = true,
	[0xFA] = true
}

-- Perfect shiny DV
local perfectShinyAtkDef = 0xFA

local function isShiny(atkdef, spdspc)
	return spdspc == 0xAA and shinyAtkDef[atkdef]
  -- return spdspc == 0xAA and atkdef == perfectShinyAtkDef
end

-- Initial save state before confirming deposit of the second Pokémon
savestate.saveslot(SLOT)
local tries = 0

while true do
	tries = tries + 1

	-- Load the saved state, advance one frame to walk the RNG, then save
	savestate.loadslot(SLOT)
	emu.frameadvance()
	savestate.saveslot(SLOT)

	-- Press A to confirm deposit (hold one frame)
	joypad.set({ A = true })
	emu.frameadvance()
	joypad.set({ A = false })

	-- Wait until the egg is created (wEggMonSpecies != 0) with timeout
	local timeout = 800
	local species = 0
	while timeout > 0 do
		emu.frameadvance()
		timeout = timeout - 1
		species = memory.read_u8(W_EGGMON_SPECIES, DOMAIN)
		if species ~= 0 then
			break
		end
	end

	if timeout == 0 then
		console.log(string.format("Try %d: timeout waiting for egg — reroll", tries))
	else
		-- Wait for DVs to be populated and stable after species is set
		local extra_timeout = 300
		local prev_atkdef, prev_spdspc = -1, -1
		local stable_count = 0
		local atkdef, spdspc = 0, 0

		while extra_timeout > 0 do
			emu.frameadvance()
			extra_timeout = extra_timeout - 1
			atkdef = memory.read_u8(W_EGGMON_DVS, DOMAIN)
			spdspc = memory.read_u8(W_EGGMON_DVS + 1, DOMAIN)

			if atkdef == prev_atkdef and spdspc == prev_spdspc then
				stable_count = stable_count + 1
			else
				stable_count = 1
				prev_atkdef, prev_spdspc = atkdef, spdspc
			end

			-- If bytes are non-zero and stable for a couple frames, accept them
			if not (atkdef == 0 and spdspc == 0) and stable_count >= 2 then
				break
			end
		end

		if atkdef == 0 and spdspc == 0 then
			console.log(string.format("Try %d: timeout waiting for DVs — reroll", tries))
		else
			if isShiny(atkdef, spdspc) then
				console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
				break
			else
				console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
			end
		end
	end
end

-- Pause the emulator once the shiny egg is found
client.pause()

