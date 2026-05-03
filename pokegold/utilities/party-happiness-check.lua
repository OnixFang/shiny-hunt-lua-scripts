local DOMAIN = "System Bus"

-- WRAM base and layout for party happiness (friendship) in pokegold
local W_PARTYMON1_HAPPINESS = 0xDA45
local PARTY_STRUCT_LENGTH = 0x30
local MAX_PARTY = 6

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

console.log("Party happiness / friendship values:")

for slot = 0, MAX_PARTY - 1 do
	local addr = W_PARTYMON1_HAPPINESS + slot * PARTY_STRUCT_LENGTH
	local value = memory.read_u8(addr, DOMAIN)

	-- If the slot is unused, the happiness byte is typically 0; skip trailing empties
	if value == 0 then
		-- Still log the first slot even if it's 0, just in case you're debugging
		if slot == 0 then
			console.log(string.format("Slot %d: %d (%s)", slot + 1, value, happiness_label(value)))
		else
			-- Assume no more party members beyond the first empty slot
			break
		end
	else
		console.log(string.format("Slot %d: %d (%s)", slot + 1, value, happiness_label(value)))
	end
end

