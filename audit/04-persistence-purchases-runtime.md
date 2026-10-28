# 04 — Persistence, receipts, live place and runtime checks

Auditor: lead (inline). Scope: `DataService`, the receipt path in `MonetizationService` + `Shared.Purchases`,
the saved place in Studio (stray scripts, part counts, settings), the spec suite, and a short Play session.

## Evidence gathered

| Check | Result |
|---|---|
| Full spec suite, Studio Edit mode (`require(ServerStorage.Tests.Runner)()`) | **711 passed, 0 failed** |
| Scripts in the place outside Rojo-managed folders | 1: `ReplicatedFirst.LoadingScreen`, which is `src/loading` (managed). **No stray QA fixtures.** |
| Workspace | 11,544 BaseParts, 2,060 MeshParts, 6 ParticleEmitters, 5 lights, StreamingEnabled = true |
| `Players.MaxPlayers` (saved in place) | 60 (dashboard value not verifiable from here) |
| Play session (~60 s, `DevMemoryStore`) | Server started, profile loaded, telemetry funnel fired (`mine_debris`, `meteor_lands`), **0 script errors / warnings** from game code in a 25 s window during a meteor |
| Console noise | `rbxassetid://203785492` "Asset type does not match requested type" ×6; not referenced by repo or any game instance (likely the test avatar / core UI) |

## Findings

### D1 — P1 — `PetMax` can be bought when it gives nothing
- **Where:** `src/shared/Purchases.luau:81-92`, `src/client/Controllers/StoreController.luau:128-146`, `src/server/Services/MonetizationService.luau:265-266`
- **What:** the grant levels each equipped pet below max. With no pets equipped, or all equipped pets already max, the
  grant returns `{cash = 0, leveled = {}}` which is treated as success: the receipt is `PurchaseGranted` and the
  notice still says "Your equipped pets are at max level!". The store card has no state for this case (only
  `StarterPack` and `PetSlot` have an "owned" check).
- **Impact:** a payer is charged Robux for nothing; a refund request / bad review waiting to happen.
- **Fix:** client: show the card as unavailable with a reason when no equipped pet is below max. Server: if the
  grant would level nothing, give an equal-value fallback (like tier-ups do) or credit it (`credits.petMax`) and
  apply it when a pet is next equipped. Add a Purchases spec case.
- **Confidence:** high (read the code end to end).

### D2 — P1 — A second receipt during a save is deferred to a later rejoin
- **Where:** `src/server/Services/MonetizationService.luau:329-331`
- **What:** while one receipt for a player is mid-save (`processing[player]`), any other receipt for the same player
  returns `NotProcessedYet`. Roblox re-invokes unprocessed receipts on the player's next join or next purchase,
  not on a short timer.
- **Impact:** buying two products quickly (two shard packs, a cash pack then an Overclock) can leave the second
  paid grant missing until the player rejoins — looks like a stolen purchase.
- **Fix:** `ProcessReceipt` may yield: wait (bounded, e.g. 10 s) for `processing[player]` to clear, then process;
  only return `NotProcessedYet` on timeout or player gone.
- **Confidence:** medium on Roblox's retry timing; high that the second receipt is not processed in-session.

### D3 — P2 — One-off products are enforced only by the client
- **Where:** `src/shared/Purchases.luau:93-105`, `StoreController.luau:133`, `OfferController.luau:191`
- **What:** `StarterPack` and `PetSlot` are "once per player" but the server grants them again if a second receipt
  arrives (stale client state, two prompts open, OfferController + Store at once). A second `PetSlot` grants nothing
  (flag already true); a second `StarterPack` grants the pack again.
- **Impact:** a second paid `PetSlot` is money for nothing.
- **Fix:** server-side: if the one-off flag is already set, give the equal-value fallback (cash/shards) and tell the player.
- **Confidence:** high.

### D4 — P2 — Crash recovery locks the player out for up to 30 minutes
- **Where:** `src/server/Services/DataService.luau:35, 177, 262-276`
- **What:** a lock is "stale" only after 30 min (`LOCK_STALE_AFTER`). If a server dies without `BindToClose`
  (crash, hard shutdown), the lock's last refresh is the last autosave. Rejoining in that window retries 8 × 5 s
  and kicks the player with the "locked" message. There is no MessagingService "please release" handshake.
- **Impact:** rare, but every affected player is kicked repeatedly after a server crash.
- **Fix:** drop the stale window to ~2–3 × the autosave interval (the lock is refreshed every 60 s), or add a
  MessagingService release request like ProfileService does.
- **Confidence:** high on the behaviour; frequency depends on crash rate.

### D5 — P2 — Uncommitted schema bump to v12 for a field nothing reads
- **Where:** working tree only: `ProfileTemplate.luau` (`version = 12`, `trialFlag = false`), `DataService.luau:140-144`,
  `RebirthReset.luau` comment, `tests/RebirthReset.spec.luau`
- **What:** looks like a test change from the LLM-work run. Nothing in `src` reads `trialFlag`. If Studio is synced
  and the place is published, every profile is written as v12 with a dead key.
- **Impact:** harmless data-wise, but a schema version is a one-way door: you can't reuse "v12" for a real migration
  without care, and a downgrade writes `version = 11` while keeping the key.
- **Fix:** revert these four files (or commit them on purpose) before the next publish.
- **Confidence:** high.

### D6 — P3 — Receipt ids are kept forever in the profile
- **Where:** `src/shared/Purchases.luau:162-167`
- **What:** `data.receipts` grows by one string per purchase forever; lookup is a linear `table.find`.
- **Impact:** negligible for years (a 4 MB profile fits ~100k ids), but whales buying micro-products daily will
  carry the list on every save.
- **Fix:** keep the last ~200 ids (Roblox only retries recent receipts), or a set keyed by id.

### D7 — P3 — Junk in the saved place
- **Where:** Studio place
- **What:** `Workspace.Part` (unanchored default 4×1×2 brick at z ≈ 2951, outside the 1080-stud map);
  `ServerStorage` carries leftover attributes `FitResult`, `FitLaps`, `FitStatus`, `TestDone` from earlier runs.
- **Fix:** delete them before saving / publishing.

### D8 — P3 — Tutorial "RUN!" competes with the meteor banner
- **Where:** `src/shared/Config/Tutorial.luau:24`; observed in Play (screenshot at step 3/10)
- **What:** card says "RUN!" with no sub-line while the top banner says "BREAK THE CRUST — Mine a node to join in!".
  The trail explains the direction but the two texts disagree for a moment.
- **Fix:** give the step a `Sub = "To the crater!"`.

## Checked and found solid
- Receipt idempotency: purchase id and grant are recorded together in memory; a failed save retries the save only,
  never the grant (`Purchases.receipt`). The meteor call inside a receipt cannot repeat on retry.
- Saves are serialized per profile, a released profile is never written again, final saves retry 4× and
  `BindToClose` waits for in-flight releases (the previous audit's A02–A04 are fixed).
- A live server whose DataStore probe fails turns players away rather than running unsaved (old A02 fixed).
- Every service clears its per-player tables on `PlayerRemoving` (checked all 20+ handlers).
- Nothing listens on `ProfileReleasing`, so no listener can yield past the final snapshot.
- Small lobbies: `Meteor.FloorPlayers = 1`, so a solo player can crack the core (old A07 fixed).
- Per-player plots are gone (one shared refinery), so the old 20-plots-vs-30-players issue no longer applies.
