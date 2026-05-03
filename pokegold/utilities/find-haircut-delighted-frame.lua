local DOMAIN = "System Bus"
local SLOT = 3

-- Search settings
local START_OFFSET = 0
local MAX_OFFSET = 600
local A_PRESS_FRAMES = 2
local RESULT_TIMEOUT = 240

-- WRAM addresses from pokegold-memory-addresses.sym
local W_SCRIPT_VAR = 0xD173
local W_CUR_PARTY_MON = 0xD005

local function pressA(frames)
    joypad.set({})
    for _ = 1, frames do
        joypad.set({ A = true })
        emu.frameadvance()
    end
    joypad.set({})
end

local function classifyResult(value)
    if value == 4 then
        return "DELIGHTED"
    elseif value == 3 then
        return "happy"
    elseif value == 2 then
        return "a little happier"
    elseif value == 1 then
        return "egg/invalid choice"
    elseif value == 0 then
        return "cancel/no choice"
    end
    return string.format("unexpected value %d", value)
end

local function waitForHaircutResult(initialScriptVar)
    local timeout = RESULT_TIMEOUT

    while timeout > 0 do
        emu.frameadvance()
        timeout = timeout - 1

        local scriptVar = memory.read_u8(W_SCRIPT_VAR, DOMAIN)
        if scriptVar ~= initialScriptVar then
            return scriptVar, timeout
        end
    end

    return nil, 0
end

console.log(string.format(
    "find-haircut-delighted-frame: offsets %d..%d, slot=%d",
    START_OFFSET,
    MAX_OFFSET,
    SLOT
))
console.log("Save SLOT at haircut party menu with target mon highlighted, then run.")

-- Save baseline state once, then iterate offsets by reloading it.
savestate.saveslot(SLOT)

for offset = START_OFFSET, MAX_OFFSET do
    savestate.loadslot(SLOT)

    local initialScriptVar = memory.read_u8(W_SCRIPT_VAR, DOMAIN)
    local curPartyMon = memory.read_u8(W_CUR_PARTY_MON, DOMAIN)

    for _ = 1, offset do
        emu.frameadvance()
    end

    pressA(A_PRESS_FRAMES)

    local resultVar = waitForHaircutResult(initialScriptVar)
    if resultVar == nil then
        console.log(string.format(
            "Offset %d: no script result (menu state/timing mismatch)",
            offset
        ))
    else
        local label = classifyResult(resultVar)
        console.log(string.format(
            "Offset %d: %s (wScriptVar=%d, partySlot=%d)",
            offset,
            label,
            resultVar,
            curPartyMon + 1
        ))

        if resultVar == 4 then
            console.log(string.format("FOUND delighted frame at offset %d", offset))
            client.pause()
            break
        end
    end
end
