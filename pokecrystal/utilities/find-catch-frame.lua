local DOMAIN = "System Bus"
local SLOT = 3

-- Search settings
local START_OFFSET = 0
local MAX_OFFSET = 600
local A_PRESS_FRAMES = 3

-- wThrownBallWobbleCount (0xD1EB) and wBattleMode (0xD22D) are in banked WRAM1 and
-- cannot be reliably read mid-animation from Lua. Only wWildMon (0xC64E) is in fixed
-- WRAM0 and is safe to poll at any time.
--
-- Strategy:
--   MIN_WAIT  : hard minimum before accepting any result (ball must have landed).
--   RESULT_TIMEOUT : total frames to poll wWildMon; if still 0, treat as failure.

-- wWildMon is set (if caught) or left 0 (if escaped) before the wobble animation starts,
-- so polling it for MIN_WAIT frames is all we need — no second phase required.
local MIN_WAIT = 100   -- frames; covers ball flight + catch decision + start of wobble

-- WRAM addresses from pokecrystal-memory-addresses.sym
local W_BATTLE_MODE = 0xD22D  -- banked; only read before animation, not during
local W_WILDMON     = 0xC64E  -- WRAM0, safe to poll always; non-zero = caught

local function pressA(frames)
    joypad.set({})
    for _ = 1, frames do
        joypad.set({ A = true })
        emu.frameadvance()
    end
    joypad.set({})
end

local function waitForCatchResult()
    -- wWildMon is set before wobble animations begin, so MIN_WAIT frames is enough:
    -- if it's still 0 after that, the pokemon already escaped.
    for _ = 1, MIN_WAIT do
        emu.frameadvance()
        if memory.read_u8(W_WILDMON, DOMAIN) ~= 0 then
            return true
        end
    end
    return false
end

console.log(string.format(
    "find-catch-frame: offsets %d..%d, slot=%d",
    START_OFFSET,
    MAX_OFFSET,
    SLOT
))
console.log("Make sure slot " .. SLOT .. " is in battle and ready to throw a ball with A.")

-- Save baseline state once; each failed try reloads, advances 1 frame, saves.
savestate.saveslot(SLOT)

for offset = START_OFFSET, MAX_OFFSET do
    savestate.loadslot(SLOT)

    -- W_BATTLE_MODE is banked, but we read it right after load before any animation starts,
    -- so the bank should still be correct here.
    local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)
    if battleMode == 0 then
        console.log("Not in battle at saved state. Reposition, then re-run script.")
        client.pause()
        break
    end

    pressA(A_PRESS_FRAMES)

    local success = waitForCatchResult()
    if success then
        console.log(string.format("SUCCESS at frame offset %d", offset))
        client.pause()
        break
    end

    console.log(string.format("Offset %d: failed catch", offset))

    -- Advance 1 frame and save so next try starts 1 frame later (no re-advance from zero).
    if offset < MAX_OFFSET then
        savestate.loadslot(SLOT)
        emu.frameadvance()
        savestate.saveslot(SLOT)
    end
end
