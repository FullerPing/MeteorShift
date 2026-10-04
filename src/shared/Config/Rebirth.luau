--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth and the cash multiplier; RebirthService applies them.
-- The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	BaseCost = 15e6, -- cash for the first rebirth ($15M, about 45 minutes in, docs/balance.md)
	CostGrowth = 5, -- each rebirth costs this many times the one before ($75M, $375M, $1.9B, ...)
	CashMult = 5, -- bar sales multiplier gained per rebirth, multiplicative (x5, x25, x125, ...); equal to CostGrowth so each rebirth takes about as long as the last
	ConfirmWindow = 3, -- seconds the panel waits for the second "Are you sure?" press
}
