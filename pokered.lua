local DOMAIN = "System Bus"
local SLOT = 2

-- Memory addresses from symbol file
local WPARTYMONS = 0xD16B
local WPARTYCOUNT = 0xD163
local MON_LEN = 0x2C
local MON_DVS_OFF = 27

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

    -- Send button A input for one frame
    joypad.set({
        A = true
    })
    emu.frameadvance()
    joypad.set({
        A = false
    })

    -- Allow frame advancement for the party struct write to complete
    for i = 1, 15 do
        emu.frameadvance()
    end

    -- New slot is (current party count - 1) after acceptance
    local slot = memory.read_u8(WPARTYCOUNT, DOMAIN) - 1
    local dv = WPARTYMONS + slot * MON_LEN + MON_DVS_OFF

    -- Read pokemon DVs
    local atkdef = memory.read_u8(dv, DOMAIN)
    local spdspc = memory.read_u8(dv + 1, DOMAIN)

    -- Check for shiny DVs
    if isShiny(atkdef, spdspc) then
        console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
        break
    else
        console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
    end
end

-- Pause the emulator once the shiny pokemon is found
client.pause()
