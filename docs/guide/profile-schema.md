# Profile schema

One DataStore record per player is everything the game remembers: a schema `version` plus the field
table below. Its shape and defaults live only in `src/server/Lib/ProfileTemplate.luau`; its version
steps live only in `DataService.migrate()` (`src/server/Services/DataService.luau:84-159`). The
current version is whatever the template's `version` field says (`ProfileTemplate.luau:7`) — this
guide deliberately stamps no number, and the spec is built the same way ("a positive integer",
never a literal — `tests/ProfileTemplate.spec.luau:20-24`).

Companions: the profile → `State` snapshot → client path is the "State flow" section of
[architecture.md](architecture.md); the economy meaning of the rebirth split is the "What survives
a rebirth" table in [economy.md](economy.md); the full pass/product story belongs to the
monetization guide — this page covers only what the profile *saves* about money from purchases.

## What is saved

Defaults cite the key's own line in `src/server/Lib/ProfileTemplate.luau`; "Rebirth" cites
`src/server/Lib/RebirthReset.luau`, whose whole `apply()` body is `:17-37` — a key **survives**
because nothing there assigns it, and resets because something does (the spec enforces exactly
that: only existing keys are assigned — `tests/ProfileTemplate.spec.luau:94-118`).

| Field(s) | Default | Main writers (service) | Rebirth |
|---|---|---|---|
| `cash` | 0 (`:8`) | added via `PlayerStateService:AddCash` on bar sales (`src/server/Services/EconomyService.luau:88`); spent by `src/server/Services/ShopService.luau:165` and `src/server/Services/UpgradeService.luau:54` | resets to the default (`RebirthReset.luau:23`) |
| `shards` (Core Shards) | 0 (`:9`) | paid by `src/server/Services/RewardService.luau` (see it and `PlayerStateService.luau:461`); spent by `src/server/Services/PerkService.luau:50` and `src/server/Services/PetService.luau:119` | survives |
| `level`, `xp` | 1, 0 (`:16-17`) | `src/server/Services/LevelService.luau:69` via `Levels.addXp` (`src/shared/Levels.luau`) | survives |
| `rebirths` | 0 (`:34`) | `src/server/Services/RebirthService.luau:64` | survives — the function never touches the count (`RebirthReset.luau:17-37`) |
| `overflow` (overstay tracking) | 0 (`:22`) | tallied on every sale (`EconomyService.luau:87`), paid at rebirth (`RebirthService.luau:58`) | cleared (`RebirthReset.luau:35`, and under keep-all `:19`) |
| `pickaxeTier`, `backpackTier` | 1, 1 (`:10-11`) | evolutions write tier + first level (`src/shared/Purchases.luau:140-141`, used by Robux tier-ups); see `ShopService.luau`; load clamps to Config (`DataService.luau:116-117`) | survive as *tiers*: kept (Head Start now grants starting cash instead) |
| `pickaxeLevel`, `backpackLevel` | 1, 1 (`:12-13`) | stat-level buys in `src/server/Services/ShopService.luau` (cost `:165`); load re-cleans (`DataService.luau:131-132`) | reset to the kept tier's first level (`RebirthReset.luau:28-29`) |
| `line` (production line level) | 1 (`:26`) | `src/server/Services/UpgradeService.luau:55`; load cleans (`DataService.luau:139`) | partial — Station Memory keeps its share (`RebirthReset.luau:33`) |
| `hopper` (ore waiting) | empty (`:27`) | deposits (`src/server/Services/RefineryService.luau:117`, auto-deposit `PlayerStateService.luau:374,417,445`); the line sim consumes it (`src/server/Lib/Refining.luau:91`) | emptied in place (`RebirthReset.luau:30-32`) |
| `refinePriority` | empty = default ore order (`:28`) | `RefineryService.luau:101` | survives |
| `bin` (bars at the post) | empty (`:29`) | sim production (`src/server/Lib/Refining.luau:94`), offline catch-up (`RefineryService.luau:179`); collected into `bars` (`:145`) | emptied |
| `progress` (fractional ore between ticks) | 0 (`:30`) | the sim (`src/server/Lib/Refining.luau`) | reset (`RebirthReset.luau:34`) |
| `bars` (carried) | empty (`:31`) | collected (`RefineryService.luau:145`); sold and cleared (`EconomyService.luau:82`) | emptied |
| `backpack` (carried ore) | empty (`:23`) | ore hits (`PlayerStateService.luau:378`); deposits drain it (`RefineryService.luau:116-123`, `PlayerStateService.luau:441-445`) | emptied |
| `decor` (placed items) | empty (`:32`) | no live writer in `src/server` as of 2026-10-18 — the rebirth clear is the only mutation (grep) | emptied with active gameplay (`RebirthReset.luau:30-32`) |
| `pets.owned` / `pets.equipped` / `pets.hatches` | all empty (`:15`; `hatches` = per-egg pity since last Epic+) | hatch/buy (`src/server/Services/PetService.luau:122-127`), pass-granted pets (`:150-151`); load cleans (`DataService.luau:151`) | survives whole (fixture-pinned: `tests/RebirthReset.spec.luau:78-88`) |
| `index` (mineral discoveries) | empty (`:33`) | `src/server/Services/IndexService.luau:91-92` | survives — index rewards/titles are recomputed from it (`tests/RebirthReset.spec.luau:65-76`) |
| `tutorialStep` | 1 = next step (`:36`) | `src/server/Services/TutorialService.luau:70` (each step completes on a real action) | survives |
| `flags.tutorialDone` / `flags.introSeen` | false (`:38-39`) | `TutorialService.luau:72,92` and `:81` | survive |
| `flags.firstMeteor` / `firstCoreReward` / `firstRefinery` | false (`:41-43`) | analytics milestones in `src/server/Services/TelemetryService.luau:284,304,345` | survive |
| `flags.gearRefund` | *not in the template* | written once by a migration (`DataService.luau:123-124`), cleared when the shop tells the player (`ShopService.luau:307-309`) | transient |
| `paidShards` | 0 | the Robux-bought part of `shards` (`Shared.ShardWallet`: shard packs, tier-up and repeat refunds); eggs spend earned shards first, perks/evolves spend bought first; v13 migration starts it at 0 | survives |
| `settings` | {} | saved Settings toggles (`Shared.PlayerSettings`, `PlayerStateService:SetSetting`) | survives |
| `credits.petMax` | 0 | a Pet Max bought with nothing to level, spent by `Purchases.applyPetMaxCredit` on the next pet put out | survives |

(v13 removed `trialFlag`, written only by an unreleased v12 trial build. v14 re-counts `rebirths` for the ×2
rebirth: an old ×5 count becomes the smallest new rank that sells bars for at least as much, rank 11 → 26, with
cash and everything else untouched — `src/server/Lib/RebirthMigration.luau`, `tests/RebirthMigration.spec.luau`.)
| `lastSeen` (offline checkpoint) | 0 (`:35`) | DataService on every autosave and release (`DataService.luau:365,305`); read for offline catch-up (`:44`) | re-stamped, never removed (`RebirthReset.luau:36`) |
| `receipts` (all processed PurchaseIds) | empty (`:52`) | `src/shared/Purchases.luau:167`; never trim (template comment) | survives (`tests/RebirthReset.spec.luau:92,98`) |
| `credits.callMeteor` / `bossMeteor` / `rebirthKeep` | 0 (`:48-50`) | bought via `src/server/Services/MonetizationService.luau`; spent at `:387`, `:409` and `RebirthService.luau:60` | survive |
| `overclockLeft`, `oreBoostLeft` (seconds, online-only) | 0 (`:53-54`) | granted in `src/shared/Purchases.luau:103-110`; ticked by `RefineryService.luau:340-346`; load-sanitized (`DataService.luau:152-153`) | survive |
| `daily` (day/lastClaim/streak/shields/quests/questBonusClaimed/week/weekly/joined) | record at `:61-71` (shields start at `Config.Daily.StartShields`, `:65`) | `src/server/Services/DailyService.luau` (rollover + claims) | survives |
| `codes` (redeemed code names) | empty (`:73`) | marked redeemed before paying (`src/server/Services/CodesService.luau:38,44`) | survives |
| `stats.meteorsJoined` / `coresCracked` / `barsSold` | 0 (`:56-58`) | `RewardService.luau:76,78` and `EconomyService.luau:83` | survive (`tests/RebirthReset.spec.luau:92,100`) |

Not saved, deliberately: game-pass ownership ("Pass ownership comes from Roblox on every join",
template comment `:45-46`), PolicyService results (runtime RemoteProperty — see
`src/server/Services/PlayerPolicyService.luau`), and leaderboard ranks (separate OrderedDataStores —
see `src/server/Services/LeaderboardService.luau`).

## The versioning contract

CLAUDE.md's four steps, expanded:

1. **Extend the template.** Add the key with its default in `ProfileTemplate.luau`; the file's own
   header promises new keys are filled into old profiles on load (its `:3-4` comment).
2. **Bump `version`.** One integer step in the template (`:7`) — never inside a migration branch
   (the final stamp `DataService.luau:157` owns it; only the two oldest historical steps, `:106`
   and `:114`, rewrote it mid-function).
3. **Add a migration branch** in `migrate()` for profiles still carrying the older number. The
   guard shape is always the same — `N` is the version that introduced the change, and it appears
   at `DataService.luau:88, 112, 120, 128, 135, 142`:

   ```lua
   if (data.version or 1) < N then
       -- translate the old shape forward; carry bought progress, refund nothing
   end
   ```

   A full step to copy is the stations-into-one-line conversion (`:133-138`, via
   `Line.fromStations`) — the same "nothing already bought is lost" promise as the economy-rework
   comment at `:145-146`.
4. **Keep `RebirthReset` consistent.** Decide survive (leave the key alone) or reset (assign from
   `Template` inside `apply`, `:23-36`), and keep [economy.md](economy.md)'s survives table true.

A profile three versions behind is fixed in **one load**: every branch whose guard passes runs in
file order, then `reconcile()` recursively fills keys the template has and the record doesn't
(called at `:286`; the function at `:74-82` — dictionaries merge, player arrays are left alone),
then `data.version = Template.version` pins the record forward (`:157`). After that, every load
still re-runs the unconditional clean passes — tier clamps `:116-117`, gear levels `:131-132`,
line `:139`, perks `:147`, overflow `:148-149`, pets `:151`, ore boost `:152-153`, level/XP
`:155-156` — so migrations only translate shapes and the `Shared.*` clean functions are the
permanent sanitizers.

## Load and save lifecycle

| Phase | Behaviour | Cite (all `src/server/Services/DataService.luau` unless said) |
|---|---|---|
| Storage | one DataStore, `PlayerData_v1` (a store name, not a schema number), key `player_<userId>`, envelope `{ data, lock }` | `:33` (fetched `:329`), `keyFor` `:161-163`, `:175`, `:226-227` |
| Join | one `UpdateAsync` claims the session lock and returns the record | `_load` `:255`, `claim` `:166-191` |
| Locked? | another live server holding the lock is retried 8 × 5 s; a lock older than 30 min is treated as dead and taken over | `:35-37`, loop `:262-272`, staleness check `:177` |
| Load failed | the player is kicked with the friendly text from `src/shared/ProfileLoadMessage.luau:6-13` (raw reasons stay in warnings) | `:273-276` |
| Prepare | fresh `Template` if no record, then `migrate` → `reconcile` | `:285-286` |
| Announce | `ProfileLoaded:Fire` — the whole server treats that as "this player exists now" | `:52`, `:296`; subscriber list in [architecture.md](architecture.md) |
| While in | autosave every 60 s (also re-stamps `lastSeen`); gameplay never writes immediately — only receipt grants save before ack (`MonetizationService.luau:342-344`, contract at `:244-246`) | `:34`, loop `:361-369`, `:365` |
| Leave | `ProfileReleasing` fires, `lastSeen` re-stamped, the final save + lock release retries 4 × with backoff | `:299-317` (`:304`, `:305`, `:309-315`) |
| Shutdown | `BindToClose` releases everyone and waits up to 25 s for the retries | `:371-382` |
| Anti-corruption | one write at a time per profile; a released profile is never written again; a write aborts if another server took the lock | header `:11-12`, `:199-207`, `:221-224` |
| No DataStore | Studio's failed probe falls back to in-memory profiles (`Profile.Memory`, `:43`, `:211-215`); `ServerStorage.DevMemoryStore = true` forces that before Play for isolated runs — the dev-hooks guide owns the hook details | `KnitInit` `:319-348`, opt-in `:321-323` |
| Live store down | a live server turns players away rather than run unsavable | `:344-346`, kick `:256-258` |

The client never sees the profile — it renders `PlayerStateService.State`, flushed at most once per
`Config.Net.StateFlushInterval`; that whole path is [architecture.md](architecture.md)'s "State
flow".

## Receipts and dedupe (saved purchase history)

`receipts` is a never-trimmed list of every processed `PurchaseId` (template comment `:52`).
`_processReceipt` (`src/server/Services/MonetizationService.luau:318-355`) runs one transaction per
receipt through `Purchases.receipt` (`src/shared/Purchases.luau:158-170`): a fresh id is granted,
inserted, then saved (`:162-167`); a repeat id skips the grant but still saves; and if the save
fails the grant and id stay paired in memory so a retry can't grant twice (header comment
`Purchases.luau:156-157`). Roblox hears `PurchaseGranted` only after the save landed
(`MonetizationService.luau:347-351`). The catalog, ids and Store placement are the monetization
guide's story, not this one.

## What the two specs pin — and what must grow

`tests/ProfileTemplate.spec.luau` pins the **shape** (run in Studio; no version literal anywhere):

| It pins | Cite |
|---|---|
| version is a positive integer, never a stamped literal | `:20-24` |
| the top-level key-coverage list — **every new saved key must be added to the list at `:27-31` or this spec fails** | `:26-34` |
| counters at 0, gear/progression at rank ≥ 1 | `:36-48` |
| inventory/index/history maps start empty | `:50-60` |
| fixed-shape members: the five perks, boolean flags, three credits, three stats, daily members | `:62-82` |
| deep copies are independent of the template | `:84-92` |
| a rebirth reset drops no key and only assigns existing ones | `:94-118` |
| keep-everything preserves the whole shape | `:120-132` |

`tests/RebirthReset.spec.luau` pins the **behaviour**: gear keeps tiers, loses levels (`:35-45`);
the line resets, or keeps the Station Memory share (`:47-51`, `:143-152`); Head Start grants a share of
the next rebirth's cost as cash (`:154-175`); inventories empty in place (`:53-63`); shards, index
bonuses and titles, pets, credits, receipts, flags, stats and preferences are untouched (`:65-107`);
no reset produces bars (`:109-117`); repeated resets don't touch the template (`:119-130`);
keep-all moves only `overflow` and `lastSeen` (`:177-197`).

Adding a saved field therefore means five coordinated edits: template key + default → version bump
(`ProfileTemplate.luau:7`) → migration branch (shape and example above) → survive-or-reset call in
`RebirthReset` (plus economy.md's table) → both specs grow: the key list at
`tests/ProfileTemplate.spec.luau:27-31` and a survival assertion in `tests/RebirthReset.spec.luau`.
Run them the usual way — `require(game.ServerStorage.Tests.Runner)()` in Studio Edit mode; the
testing guide covers the Runner.

*Cite hygiene: this page was written 2026-10-18 against the working tree of the four profile files
mid-migration; because it stamps no version number, none of it depends on that number's value.*
