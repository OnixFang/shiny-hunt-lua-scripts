local DOMAIN = "System Bus"

-- WRAM from pokecrystal-memory-addresses.sym (bank 01)
local W_PARTYCOUNT = 0xDCD7
local W_PARTYMON1_HAPPINESS = 0xDCFA
local PARTY_STRUCT_LENGTH = 0x30

-- Optional: simple labels for evolution thresholds (Gen 2 Espeon/Umbreon)
local function happiness_label(value)
	if value >= 220 then
		return "ready for Espeon/Umbreon evolution (>=220)"
	elseif value >= 200 then
		return "very high (200–219)"
	elseif value >= 150 then
		return "high (150–199)"
	elseif value >= 100 then
		return "medium (100–149)"
	else
		return "low (<100)"
	end
end

local count = memory.read_u8(W_PARTYCOUNT, DOMAIN)
if count == 0 then
	console.log("Party is empty (wPartyCount = 0).")
	return
end

console.log(string.format("Party happiness / friendship (%d mon):", count))

for slot = 0, count - 1 do
	local addr = W_PARTYMON1_HAPPINESS + slot * PARTY_STRUCT_LENGTH
	local value = memory.read_u8(addr, DOMAIN)
	console.log(string.format("Slot %d: %d (%s)", slot + 1, value, happiness_label(value)))
end
