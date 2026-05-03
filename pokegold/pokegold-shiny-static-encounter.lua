local DOMAIN = "System Bus"
local SLOT = 2

-- Memory addresses from pokegold symbol file (WRAM bank 1)
local W_BATTLE_MODE = 0xD116 -- 0=overworld, 1=wild, 2=trainer
local W_ENEMYMON_SPECIES = 0xD0EF
local W_ENEMYMON_DVS = 0xD0F5

-- Species byte to hunt (internal index, not National Dex). Change this when targeting
-- another static/roamer script encounter. Example: Ho-Oh is 0xFA (see constants/pokemon_constants.asm).
local TARGET_SPECIES = 0xFA -- Ho-Oh

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
    emu.frameadvance()
    savestate.saveslot(SLOT)

    -- Send button A input for one frame
    joypad.set({})
    for i = 1, 3 do -- or 3 if you ever see rare misses
        joypad.set({ A = true })
        emu.frameadvance()
    end
    joypad.set({})

    -- Wait until wild battle, correct species, and DVs stable for 2 frames.
    -- Skips the brief wEnemyMon clear window (DVs read as $0000). True $0000 DVs are vanishingly rare and would time out.
    local timeout = 400
    local prevAtkdef, prevSpdspc = nil, nil
    local dvsReady = false
    while timeout > 0 do
        emu.frameadvance()
        timeout = timeout - 1
        local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
        local species = memory.read_u8(W_ENEMYMON_SPECIES, DOMAIN)
        if battleMode == 1 and species == TARGET_SPECIES then
            local atkdef = memory.read_u8(W_ENEMYMON_DVS, DOMAIN)
            local spdspc = memory.read_u8(W_ENEMYMON_DVS + 1, DOMAIN)
            local notCleared = atkdef ~= 0 or spdspc ~= 0
            if
                prevAtkdef ~= nil
                and prevAtkdef == atkdef
                and prevSpdspc == spdspc
                and notCleared
            then
                dvsReady = true
                break
            end
            prevAtkdef, prevSpdspc = atkdef, spdspc
        else
            prevAtkdef, prevSpdspc = nil, nil
        end
    end

    if not dvsReady then
        console.log(string.format("Try %d: timeout waiting for wild + species + DVs — check TARGET_SPECIES or increase timeout", tries))
    end

    -- Read Pokemon DVs
    local atkdef = memory.read_u8(W_ENEMYMON_DVS, DOMAIN)
    local spdspc = memory.read_u8(W_ENEMYMON_DVS + 1, DOMAIN)

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
