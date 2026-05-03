local DOMAIN = "System Bus"
local W_BREEDMON1_SPECIES = 0xDC57
local W_BREEDMON1_DVS     = 0xDC6C
local W_BREEDMON2_SPECIES = 0xDC90
local W_BREEDMON2_DVS     = 0xDCA5
local function splitDv(byte)
  local atk_or_spd = math.floor(byte / 0x10)
  local def_or_spc = byte % 0x10
  return atk_or_spd, def_or_spc
end
local function dumpBreedmon(slotName, speciesAddr, dvsAddr)
  local species = memory.read_u8(speciesAddr, DOMAIN)
  local atkdef  = memory.read_u8(dvsAddr, DOMAIN)
  local spdspc  = memory.read_u8(dvsAddr + 1, DOMAIN)
  local atkDv, defDv = splitDv(atkdef)
  local spdDv, spcDv = splitDv(spdspc)
  console.log(string.format(
    "%s: species=%d ATK=%d DEF=%d SPD=%d SPC=%d RAW[ATKDEF=%02X SPDSPC=%02X]",
    slotName, species, atkDv, defDv, spdDv, spcDv, atkdef, spdspc
  ))
end
dumpBreedmon("BreedMon1", W_BREEDMON1_SPECIES, W_BREEDMON1_DVS)
dumpBreedmon("BreedMon2", W_BREEDMON2_SPECIES, W_BREEDMON2_DVS)