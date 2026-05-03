local DOMAIN = "System Bus"

-- WRAM bank 1 (pokegold.sym)
local W_BATTLE_MODE = 0xD116 -- 0=overworld, 1=wild, 2=trainer
local W_ENEMYMON_HP = 0xD0FF
local W_ENEMYMON_MAXHP = 0xD101

local function read_u16_be(addr)
    local hi = memory.read_u8(addr, DOMAIN)
    local lo = memory.read_u8(addr + 1, DOMAIN)
    return hi * 0x100 + lo
end

local lastBattleMode = -1
local lastHP = -1
local lastMaxHP = -1

while true do
    local battleMode = memory.read_u8(W_BATTLE_MODE, DOMAIN)

    if battleMode ~= 0 then
        local curHP = read_u16_be(W_ENEMYMON_HP)
        local maxHP = read_u16_be(W_ENEMYMON_MAXHP)

        -- Show values on-screen every frame while in battle.
        gui.text(2, 20, string.format("Enemy HP: %d / %d", curHP, maxHP))

        -- Log only on battle start or HP change to reduce spam.
        if battleMode ~= lastBattleMode or curHP ~= lastHP or maxHP ~= lastMaxHP then
            console.log(string.format("Enemy HP: %d / %d (battleMode=%d)", curHP, maxHP, battleMode))
        end

        lastHP = curHP
        lastMaxHP = maxHP
    elseif lastBattleMode ~= 0 then
        console.log("Not in battle.")
    end

    lastBattleMode = battleMode
    emu.frameadvance()
end
