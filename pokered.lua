local DOMAIN = "System Bus"
local PRE = "pre_accept.State"

local WPARTYMONS = 0xD16B -- from .sym
local WPARTYCOUNT = 0xD163 -- from .sym
local MON_LEN = 0x2C
local MON_DVS_OFF = 27

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

local function isShiny(atkdef, spdspc)
    return spdspc == 0xAA and shinyAtkDef[atkdef]
end

savestate.save(PRE)
local tries = 0
while true do
    tries = tries + 1
    savestate.load(PRE)

    -- Advance a unique number of frames before accepting to change RNG state
    for i = 1, tries do
        emu.frameadvance()
    end

    -- Clean input: ensure A is released, then press for one frame
    joypad.set({
        A = false
    })
    emu.frameadvance()
    joypad.set({
        A = true
    })
    emu.frameadvance()
    joypad.set({
        A = false
    })

    -- Allow a couple frames for the party struct write to complete
    for i = 1, 15 do
        emu.frameadvance()
    end

    -- New slot is (current party count - 1) after acceptance
    local slot = memory.read_u8(WPARTYCOUNT, DOMAIN) - 1
    local dv = WPARTYMONS + slot * MON_LEN + MON_DVS_OFF
    local atkdef = memory.read_u8(dv, DOMAIN)
    local spdspc = memory.read_u8(dv + 1, DOMAIN)

    if isShiny(atkdef, spdspc) then
        console.log(string.format("Shiny! Tries=%d ATKDEF=%02X SPDSPC=%02X", tries, atkdef, spdspc))
        break
    else
        console.log(string.format("Try %d: ATKDEF=%02X SPDSPC=%02X — reroll", tries, atkdef, spdspc))
    end
end
client.pause()
