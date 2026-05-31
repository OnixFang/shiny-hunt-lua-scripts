local DOMAIN = "System Bus"
local SLOT = 2

-- After A, wait until wPartyCount increases (gift applied) or cap (hang / bad save).
local MAX_WAIT_FRAMES = 480
-- Extra frames after count bumps so WRAM is stable (defensive).
local SETTLE_FRAMES = 2

-- Memory addresses from pokegold symbol file (WRAM bank 1)
-- wPartyMons, wPartyCount; party_struct has PARTYMON_STRUCT_LENGTH=48, DVs at offset 21
local WPARTYMONS = 0xDA2A
local WPARTYCOUNT = 0xDA22
local MON_LEN = 48      -- PARTYMON_STRUCT_LENGTH
local MON_DVS_OFF = 21 -- offset to DVs in party_struct (MON_DVS)

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

-- Shiny function to determine shininess
local function isShiny(atkdef, spdspc)
    return spdspc == 0xAA and shinyAtkDef[atkdef]
end

-- Initial save state before setup
savestate.saveslot(SLOT)
local tries = 0

-- Shiny hunt loop
while true do
    tries = tries + 1

    -- Advance a frame and save to walk the RNG state
    savestate.loadslot(SLOT)
    emu.frameadvance()
    savestate.saveslot(SLOT)

    local party_count_before = memory.read_u8(WPARTYCOUNT, DOMAIN)

    -- Send button A input for one frame
    joypad.set({
        A = true
    })
    emu.frameadvance()
    joypad.set({
        A = false
    })

    -- Wait until givepoke increases party count (fanfare + script), or timeout
    local waited = 0
    while waited < MAX_WAIT_FRAMES do
        emu.frameadvance()
        waited = waited + 1
        local c = memory.read_u8(WPARTYCOUNT, DOMAIN)
        if c > party_count_before then
            for _ = 1, SETTLE_FRAMES do
                emu.frameadvance()
            end
            break
        end
    end

    local party_count_after = memory.read_u8(WPARTYCOUNT, DOMAIN)
    if party_count_after <= party_count_before then
        console.log(string.format(
            "Try %d: party count stayed at %d after %d frames — wrong save timing or full party; skip",
            tries,
            party_count_before,
            MAX_WAIT_FRAMES
        ))
    else
        -- New mon is always the last slot after givepoke
        local slot = party_count_after - 1
        local dv = WPARTYMONS + slot * MON_LEN + MON_DVS_OFF

        local atkdef = memory.read_u8(dv, DOMAIN)
        local spdspc = memory.read_u8(dv + 1, DOMAIN)

        if isShiny(atkdef, spdspc) then
            console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X (waited %d f)", tries, atkdef, spdspc, waited))
            break
        else
            console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll (waited %d f)", tries, atkdef, spdspc, waited))
        end
    end
end

-- Pause the emulator once the shiny pokemon is found
client.pause()
