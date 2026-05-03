local DOMAIN = "System Bus"
local SLOT = 2

-- Memory layout constants (WRAM bank 1)
local WPARTYMONS = 0xDA2A
local WPARTYCOUNT = 0xDA22
local PARTY_STRUCT_LENGTH = 0x30
local MON_DVS_OFF = 0x15

local TARGET_DEFENSE_DV = 10          -- defense DV to lock in
local TARGET_SPECIAL_DV_1 = 10        -- primary special DV to lock in (e.g. 10 for shiny setups)
local TARGET_SPECIAL_DV_2 = 2         -- alternate special DV to allow (e.g. 2 for specific breeding setups)

-- Species-specific female Attack-DV thresholds.
-- Key: species ID, Value: maximum Attack DV that is still female.
-- Example: Eevee (133) is 87.5% male, so female if Attack DV <= 1.
-- Add entries here as you hunt other gifts; everything else uses the 50/50 default.
local FEMALE_ATTACK_DV_MAX_BY_SPECIES = {
    [133] = 1,  -- Eevee
}

-- Default for 50/50 gender ratio species: female if Attack DV <= 7.
local DEFAULT_FEMALE_ATTACK_DV_MAX = 7

local function getAttackDv(atkDefByte)
    return math.floor(atkDefByte / 0x10)
end

local function getDefenseDv(atkDefByte)
    return atkDefByte % 0x10
end

local function splitDv(byteValue)
    return math.floor(byteValue / 0x10), byteValue % 0x10
end

local function isFemaleByAtkDv(atkDv, species)
    local maxAtk = FEMALE_ATTACK_DV_MAX_BY_SPECIES[species] or DEFAULT_FEMALE_ATTACK_DV_MAX
    return atkDv <= maxAtk
end

local function describeFailure(defMatch, spcMatch, genderMatch)
    if not defMatch and not spcMatch and not genderMatch then
        return "defense DV mismatch, special DV mismatch, gender mismatch"
    elseif not defMatch and not spcMatch then
        return "defense DV mismatch, special DV mismatch"
    elseif not defMatch and not genderMatch then
        return "defense DV mismatch, gender mismatch"
    elseif not spcMatch and not genderMatch then
        return "special DV mismatch, gender mismatch"
    elseif not defMatch then
        return "defense DV mismatch"
    elseif not spcMatch then
        return "special DV mismatch"
    elseif not genderMatch then
        return "gender mismatch"
    end
    return ""
end

savestate.saveslot(SLOT)
local tries = 0

while true do
    tries = tries + 1

    savestate.loadslot(SLOT)
    emu.frameadvance()
    savestate.saveslot(SLOT)

    joypad.set({
        A = true
    })
    emu.frameadvance()
    joypad.set({
        A = false
    })

    local prevCount = memory.read_u8(WPARTYCOUNT, DOMAIN)
    local newCount = prevCount
    local countTimeout = 800
    while countTimeout > 0 and newCount <= prevCount do
        emu.frameadvance()
        newCount = memory.read_u8(WPARTYCOUNT, DOMAIN)
        countTimeout = countTimeout - 1
    end

    if newCount <= prevCount then
        console.log(string.format("Try %d: waited too long for party slot increase - reroll", tries))
        goto continue_search
    end

    local slot = newCount - 1
    if slot < 0 or slot >= 6 then
        console.log(string.format("Try %d: party slot %d invalid - reroll", tries, slot + 1))
        goto continue_search
    end

    local dvAddr = WPARTYMONS + slot * PARTY_STRUCT_LENGTH + MON_DVS_OFF

    local atkdef, spdspc = 0, 0
    local prevAtk, prevSpd = -1, -1
    local stableFrames = 0
    local dvTimeout = 160
    while dvTimeout > 0 do
        local currentAtk = memory.read_u8(dvAddr, DOMAIN)
        local currentSpd = memory.read_u8(dvAddr + 1, DOMAIN)

        if currentAtk == prevAtk and currentSpd == prevSpd then
            stableFrames = stableFrames + 1
        else
            stableFrames = 1
            prevAtk = currentAtk
            prevSpd = currentSpd
        end

        if stableFrames >= 2 then
            atkdef = currentAtk
            spdspc = currentSpd
            break
        end

        emu.frameadvance()
        dvTimeout = dvTimeout - 1
    end

    if stableFrames < 2 then
        atkdef = prevAtk
        spdspc = prevSpd
    end

    if atkdef == 0 and spdspc == 0 then
        console.log(string.format("Try %d: DVs still zero - reroll", tries))
        goto continue_search
    end

    -- Read species so we can apply species-specific gender ratios.
    local monBase = WPARTYMONS + slot * PARTY_STRUCT_LENGTH
    local species = memory.read_u8(monBase, DOMAIN)

    local atkDv, defDv = splitDv(atkdef)
    local spdDv, spcDv = splitDv(spdspc)
    local defMatches = defDv == TARGET_DEFENSE_DV
    local spcMatches = (spcDv == TARGET_SPECIAL_DV_1) or (spcDv == TARGET_SPECIAL_DV_2)
    local genderMatches = isFemaleByAtkDv(atkDv, species)
    local statusMessage = describeFailure(defMatches, spcMatches, genderMatches)

    if defMatches and spcMatches and genderMatches then
        console.log(string.format("Target found on try %d: ATK=%d DEF=%d SPD=%d SPC=%d RAW[ATKDEF=%02X SPDSPC=%02X]", tries, atkDv, defDv, spdDv, spcDv, atkdef, spdspc))
        break
    else
        console.log(string.format("Try %d: ATK=%d DEF=%d SPD=%d SPC=%d RAW[ATKDEF=%02X SPDSPC=%02X] - %s", tries, atkDv, defDv, spdDv, spcDv, atkdef, spdspc, statusMessage))
    end

    ::continue_search::
end

client.pause()
