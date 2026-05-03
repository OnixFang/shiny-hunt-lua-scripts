local DOMAIN = "System Bus"
local SLOT = 3

-- Search settings
local START_OFFSET = 0
local MAX_OFFSET = 600
local A_PRESS_FRAMES = 2
local RESULT_TIMEOUT = 420

-- WRAM addresses from pokegold.sym
local W_BATTLE_MODE = 0xD116 -- 0=overworld, 1=wild, 2=trainer
local W_THROWN_BALL_WOBBLE_COUNT = 0xD0D4
local W_WILDMON = 0xD14F -- non-zero when catch succeeds

local function pressA(frames)
    joypad.set({})
    for _ = 1, frames do
        joypad.set({ A = true })
        emu.frameadvance()
    end
    joypad.set({})
end

local function waitForCatchResult()
    local timeout = RESULT_TIMEOUT
    local throwStarted = false

    while timeout > 0 do
        emu.frameadvance()
        timeout = timeout - 1

        local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
        local wobbleCount = memory.read_u8(W_THROWN_BALL_WOBBLE_COUNT, DOMAIN)
        local wildMon = memory.read_u8(W_WILDMON, DOMAIN)

        if wobbleCount > 0 then
            throwStarted = true
        end

        -- Catch success is decided before animation and sets wWildMon non-zero.
        if wildMon ~= 0 then
            return true, throwStarted, timeout
        end

        -- If battle already ended and no caught species was set, treat as failure.
        if throwStarted and battleMode == 0 then
            return false, true, timeout
        end
    end

    return false, throwStarted, 0
end

console.log(string.format(
    "find-catch-frame: offsets %d..%d, slot=%d",
    START_OFFSET,
    MAX_OFFSET,
    SLOT
))
console.log("Make sure SLOT state is in battle and ready to throw a ball with A.")

-- Save baseline state once, then iterate offsets by reloading it.
savestate.saveslot(SLOT)

for offset = START_OFFSET, MAX_OFFSET do
    savestate.loadslot(SLOT)

    local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
    if battleMode == 0 then
        console.log("Not in battle at saved state. Reposition, then re-run script.")
        client.pause()
        break
    end

    for _ = 1, offset do
        emu.frameadvance()
    end

    pressA(A_PRESS_FRAMES)

    local success, throwStarted = waitForCatchResult()
    if success then
        console.log(string.format("SUCCESS at frame offset %d", offset))
        client.pause()
        break
    end

    if not throwStarted then
        console.log(string.format("Offset %d: throw did not start (A timing/menu state mismatch)", offset))
    else
        console.log(string.format("Offset %d: failed catch", offset))
    end
end
