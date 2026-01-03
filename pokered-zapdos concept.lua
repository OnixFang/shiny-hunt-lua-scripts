local DOMAIN = "System Bus"
local WENEMY_DVS = 0xcff1 -- replace with wEnemyMonDVs from .sym

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

while true do
    emu.frameadvance()
    local atkdef = memory.read_u8(WENEMY_DVS, DOMAIN)
    local spdspc = memory.read_u8(WENEMY_DVS + 1, DOMAIN)
    if atkdef ~= 0 or spdspc ~= 0 then
        if isShiny(atkdef, spdspc) then
            console.log(string.format("Zapdos shiny! ATKDEF=%02X SPDSPC=%02X", atkdef, spdspc))
        else
            console.log(string.format("Zapdos not shiny: ATKDEF=%02X SPDSPC=%02X", atkdef, spdspc))
        end
        break
    end
end
