--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth and the cash multiplier; RebirthService applies them.
-- The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	BaseCost = 10e6, -- cash for the first rebirth ($10M)
	CostGrowth = 10, -- each rebirth costs this many times the one before ($100M, $1B, ...)
	CashMult = 2, -- bar sales multiplier gained per rebirth, multiplicative (x2, x4, x8, ...)
	ConfirmWindow = 3, -- seconds the panel waits for the second "Are you sure?" press
}
