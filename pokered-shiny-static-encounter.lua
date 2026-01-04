local DOMAIN = "System Bus"
local SLOT = 2

-- Memory addresses from symbol file
local W_IS_IN_BATTLE = 0xD057
local W_ENEMYMON_DVS = 0xCFF1

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

    -- Wait until the battle flag is set and the enemy struct is populated
    local timeout = 300
    while timeout > 0 do
        emu.frameadvance()
        timeout = timeout - 1
        local inBattle = memory.read_u8(W_IS_IN_BATTLE, DOMAIN)
        if inBattle ~= 0 then
            -- wait until DV bytes are non-zero
            local dv_ready =
                memory.read_u8(W_ENEMYMON_DVS, DOMAIN) ~= 0 or memory.read_u8(W_ENEMYMON_DVS + 1, DOMAIN) ~= 0
            if dv_ready then
                break
            end
        end
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
