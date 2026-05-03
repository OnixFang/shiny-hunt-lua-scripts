local DOMAIN = "System Bus"
local W_EGGMON_DVS = 0xDCDB -- first byte, second byte at +1
local atkdef = memory.read_u8(W_EGGMON_DVS, DOMAIN)
local spdspc = memory.read_u8(W_EGGMON_DVS + 1, DOMAIN)

console.log(string.format("ATKDEF=%02X SPDSPC=%02X", atkdef, spdspc))