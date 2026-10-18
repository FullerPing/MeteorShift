# Dev hooks

MeteorShift's developer tooling is deliberately small: eight command-bar `BindableFunction`s that exist only in Studio, a handful of `Dev*` place attributes that Studio-only readers honour, two Studio helper buttons on the HUD, two client remotes that no-op outside Studio, and five chat commands whose live-server half (`/give`, `/giveall`) is the only dev tool a published server honours. `CLAUDE.md:13` points here; the human-facing twin is `README.md` "Working on it" (`README.md:203-229`) — this guide is the dev-tooling half of that section, the Runner workflow lives in the testing guide, and quickstart steps 1-2 stay in the README.

Naming trap first: `src/shared/Config/Hooks.luau` and `Shared.Hooks` are *engagement* hooks (Rich Vein, Golden Meteor, Supply Crate — variable-ratio rewards, header `:1-12`). They have nothing to do with this page.

## Command-bar hooks (Studio only)

All eight are created inside `RunService:IsStudio()` guards (`src/server/Main.server.luau:45`, `src/server/Services/MonetizationService.luau:495`), so `README.md:210`'s "none exist in a live server" is literally true — the instances are never parented on a published server. Call them from the command bar during Play, e.g. `game.ServerStorage.DevGrant:Invoke(game.Players:GetPlayers()[1], 10e6)`. Every one lives under `ServerStorage`.

| Hook | Invoke | Does | Returns |
|---|---|---|---|
| DevGrant | `(player, cash?, ore?, shards?, pickaxeTier?)` — every arg after the player optional | `AddCash` / `AddOre` / `AddShards`; optional pickaxe tier clamped 1-8 (`#Config.Pickaxes`) and restyled | the player's profile (`Main.server.luau:49-70`, `:68`) |
| DevMineral | `(player, id)` | `IndexService:Award` through the real award path (toast, page announcement, title); a page id (`"Iron"`) awards every mineral on that page | the profile's index (`:77-92`, `:89-90`) |
| DevBench | `(player, swings)` | measures the ore hot path: `AddOre` ×swings while the player borrows an emptied top-tier backpack (`:110-113`), own one restored on every exit path (`:131-138`) | `{swings, elapsedMs, sends}` (`:124-125`) |
| DevMeteor | `("Crystal")` — no player arg | `MeteorService:DevSpawn` (`:146-151`) | prose of what will happen (`MeteorService.luau:712-733`) |
| DevPet | `(player, petId, level?)` | grants the pet free of the shard cost at `level` (clamped 1 to `Config.Pets.MaxLevel` = 10, `Main.server.luau:164`; `Config/Pets.luau:42`) and equips it if a slot is free | the pets table (`:157-171`) |
| DevLevel | `(player, level)` | `Levels.clean` — sets the player level (clamped 1 to `Config.Levels.MaxLevel` = 50) and clears XP (`src/shared/Levels.luau:90-96`) | the level (`Main.server.luau:176-188`) |
| DevGear | `(player, pickaxeTier?, backpackTier?)` — `nil` leaves one as is | the same `setGear` the chat commands use: tiers clamped 1-8 (`Config/Pickaxes.luau:21-30`, `Config/Backpacks.luau:15-24`), stat levels set to the tier's first level, pickaxe restyled | both gear names (`:27-43`, `:190-193`) |
| DevProduct | `(player, productKey)` | runs the *real* product grant + save path without inventing a receipt or touching MarketplaceService (`MonetizationService.luau:357-369`) — `README.md:15` stresses it "does not represent a Marketplace purchase" | `(boolean, string?)`, save failure reported separately (`:374-376`) |

Gotchas the code actually enforces:

- **DevGrant's `ore` argument is always `iron`** — `PlayerStateService:AddOre(player, "iron", ore)` (`Main.server.luau:56`); use `DevMineral` for index coverage, not ore types.
- **The return is a copy.** A `BindableFunction` return crosses to the command bar serialized, and `CLAUDE.md:53` states it plainly: `DevGrant:Invoke(player)` "returns a copy of the profile" — it is the sanctioned state-inspection window during Play (see "During Play"), not a lever for mutating live state.
- **DevBench expects one snapshot.** It waits `Config.Net.StateFlushInterval × 2` = 0.4 s (`Main.server.luau:123`; 0.2 s in `src/shared/Config/Net.luau:9`) because State replication is batched (`PlayerStateService:StateSendCount`, `src/server/Services/PlayerStateService.luau:210-214`) — a `sends` above 1 means batching regressed.
- **DevMeteor timing.** During a countdown it swaps the announced type and lands in `Config.Meteor.StreakLeadTime` = 10 s; with a meteor down, that one breaks its wait early (`MeteorService.luau:627`, `devNext ~= nil`) and the asked-for one lands 10 s into the *next* countdown (`MeteorService.luau:707-733`; `src/shared/Config/Meteor.luau:15`). Type match is case-insensitive here (`:714-718`).
- **README coverage.** The README command-bar block (`README.md:214-220`) documents six of the seven `Main.server` hooks — `DevPet` is missing there (it lists it only in the pets bullet, `README.md:69`; `CLAUDE.md:13` has the complete roster). A4's re-home should carry all seven.

## Dev\* attributes

Every reader below checks `RunService:IsStudio()` *before* honouring the value, so an attribute left in a published place is inert — `RunService:IsStudio()` is false there and the checks short-circuit (`DataService.luau:321`, `ActivityService.luau:56`, `MeteorService.luau:207`, `MonetizationService.luau:101`, `DailyService.luau:43`, `LeaderboardService.luau:141`, `LandingFXController.luau:1607`, `MeteorFXController.luau:78`, `AtmosphereController.luau:104`). With no attribute set, `GetAttribute` returns `nil` and every hook no-ops — the "set them to use them" model of `README.md:210`.

| Attribute | Host and type | Read | Effect |
|---|---|---|---|
| DevMemoryStore | `ServerStorage`, boolean `== true` | once at startup: `DataService:KnitInit` skips the DataStore probe and runs session-memory profiles (`src/server/Services/DataService.luau:319-323`); `LeaderboardService:KnitStart` skips the OrderedDataStores (`src/server/Services/LeaderboardService.luau:140-147`) | isolates a run from every live DataStore. **Set BEFORE Play** — both readers run at start (`README.md:15`, `CLAUDE.md:13`) — and **clear before saving the place** (`CLAUDE.md:13`) |
| DevMeteorType | `ServerStorage`, string exactly one of the `Config.Meteor.Types` ids (`Iron`, `Ice`, `Crystal`, `Alien`) | once per countdown, in `pickType` (`MeteorService.luau:205-209`, called at `:664`) | forces the type and skips the boss-count/golden-roll below it (`:210-218`); wrong case silently ignored (`:207`); mid-session changes take effect from the next countdown (`README.md:226`) |
| DevPasses | `ServerStorage`, string of comma/space-separated keys | at ownership resolve (`MonetizationService.luau:194-195`) and live to every player in the session via `GetAttributeChangedSignal` (`:502-506`) | grants those passes; keys validated against `Config.Monetization.Passes` (`:104-106`; the key list is `Monetization.luau:54`'s `PassOrder`, e.g. `TwoXOre`, `VIP`) |
| DevFakeTiers | `ServerStorage`, string like `"1,1,1,8"` | fresh on every `GetActivePickaxes` call (`src/server/Services/ActivityService.luau:55-61`) | adds a pretend active player per number, each with a fresh tier-clamped pickaxe, so meteor sizing is testable solo; the meteor model's `ServerPower` attribute shows what it was sized for (`MeteorService.luau:418`, `:538`; `README.md:225`) |
| DevDayOffset | `ServerStorage`, number of days | on every `DailyService` clock read (`src/server/Services/DailyService.luau:42-45`) | shifts the daily-rewards clock to test streaks, shields and resets (`DailyService.luau:5`; `README.md:125`) |
| DevHudHelpersVisible | `Workspace`, boolean `== true` | once when the HUD builds | shows the two Studio helper buttons (next section) (`src/client/Controllers/HUDController.luau:438-445`; `README.md:210`) |
| DevLandingFX | `ReplicatedStorage`, boolean `== false` | per state update, plus a live re-evaluation on change inside Studio | `false` tears down the Ice/Crystal landing scenes on every client (`LandingFXController.luau:1605-1613`, `:1659-1663`); absent or `true` leaves them on (`== false` test, `:1607`; `README.md:201`) |
| DevMeteorApproachFX | `ReplicatedStorage`, boolean `== false` | at streak start and on change | `false` skips the whole approach-fireball build (`MeteorFXController.luau:73-80` — `README.md:229` enumerates fireball, fire, light, trail, smoke, rumble, approach shake) and zeroes the approach mood weight (`src/client/Controllers/AtmosphereController.luau:103-106`); a mid-play toggle clears an in-flight streak (`MeteorFXController.luau:391-397`). Set `true` or remove to restore (`README.md:229`) |
| DevWorldMap | `Workspace`, string `"Map_Redesign"` (the only honoured value) | on every world lookup | Studio-only staging root: swaps `workspace.Map` → `Map_Redesign` and `ServerStorage.Assets` → `Assets_Redesign` (`src/shared/WorldMap.luau:2`, `:6-12`, `:14-24`) — the map-redesign-era staging switch |

## Studio HUD helpers

The whole helper frame is built `if RunService:IsStudio()` and its `Visible` is the *static* attribute read `workspace:GetAttribute("DevHudHelpersVisible") == true` (`HUDController.luau:437-445`) — set it before Play, as `README.md:210` says; toggling mid-session won't move it. Inside it (`README.md:211-212`):

- **[Studio] Meteor now** (`DevSkip`, visible only during a countdown, `HUDController.luau:451-466`) → `MeteorService.Client:DevSkipCountdown`, which sets the countdown to the last `StreakLeadTime` = 10 s (`MeteorService.luau:736-741`).
- **[Studio] Away 1 hour** (`DevAway`, `HUDController.luau:467-479`) → `RefineryService.Client:DevSimulateAway(3600)`, which runs the real `CatchUp` + `Refresh` with the seconds clamped to 0-24 h, so the "While you were away" panel really opens (`src/server/Services/RefineryService.luau:274-280`).

These two are the only dev hooks that are *client-callable remotes* — they exist on a live server but no-op there: the server side checks `not RunService:IsStudio()` and returns (`MeteorService.luau:739`, `RefineryService.luau:277`), and the skip carries a 1 s RequestGate (`MeteorService.luau:737-738`).

## Chat commands

The five `TextChatCommand`s bind unconditionally (`Main.server.luau:196-278`) but check permission on every trigger — `Admins.can(source.UserId, RunService:IsStudio())` (`:206-209`) — which is `true` for everyone in Studio and on a live server only for the user ids in `src/server/Lib/Admins.luau` (`:7-17`; add a teammate by appending `[<userId>] = "<name>"`, `:2-4`). Anyone else is ignored without a reply (`README.md:222`). The reply is printed server-side and shown to the sender as a HUD notice via `ShopService.Client.Notice` (`Main.server.luau:213-214`); only the first word after the alias reaches the handler (`:212`).

| Command | Args | Backing |
|---|---|---|
| `/meteor` | `<Iron\|Ice\|Crystal\|Alien>`, any case; no arg returns the "No meteor type …" usage string | `MeteorService:DevSpawn` (`Main.server.luau:219-221`; `MeteorService.luau:707-733`) |
| `/pickaxe` | tier `1-8`; no arg returns a usage string | `setGear(player, tier, nil)` (`Main.server.luau:222-225`) |
| `/backpack` | tier `1-8`; no arg returns a usage string | `setGear(player, nil, tier)` (`:226-229`) |
| `/give` | `<player\|me\|all\|everyone\|*> cash\|shards <whole ≥1> \| pickaxe\|backpack <1-8> \| pet <id-or-name> [level 1-10]` | full text to `AdminGive.parse` (`Main.server.luau:273-275`; `src/server/Lib/AdminGive.luau:33`, `:65-100`); recipient found by exact name/display name, else unique prefix, `me` = the giver (`:104-132`) |
| `/giveall` | same items as `/give`, without the target | rewritten to `/give all …` (`Main.server.luau:276-278`) |

Coverage note for A4: `README.md:222` and `CLAUDE.md:13` name only `/meteor`, `/pickaxe`, `/backpack` — `/give` and `/giveall` exist in code and are documented nowhere else (`Main.server.luau:273-278`).

`/give` semantics that make it safe on a live server: a gift **only ever adds** — a gear tier or pet level the recipient already has or beats is refused, nothing is taken away (`AdminGive.luau:4-6`, `:148-152`, `:159-161`), the giver is told what happened and each recipient gets a notice (`Main.server.luau:230-249`). The parse and permission rules are pure modules with specs — `tests/Admins.spec.luau` and `tests/AdminGive.spec.luau` run them without a place (`Admins.luau:11`, `AdminGive.luau:6`).

## Studio countdown override

In Studio a countdown lasts `Config.Meteor.StudioCountdown` = 25 s (`MeteorService.luau:183-187`; `src/shared/Config/Meteor.luau:34`); on a live server the first countdown is 90 s and every later one 180 s (`src/shared/Config/Meteor.luau:8-9`, used via `MeteorService.luau:42`). To test the real timings, set `Meteor.StudioCountdown = nil` (`Config/Meteor.luau:34` is typed `number?` for exactly that). Note: `README.md:208` still calls the real timings "2:00 / 4:00" — stale; the code says 1:30 / 3:00 (`Meteor.luau:8-9`), and A4 must not carry the claim over.

## Safety, as coded

- The eight command-bar hooks cannot be invoked live because the `BindableFunction` instances are only parented under `IsStudio()` (`Main.server.luau:45`, `MonetizationService.luau:495`).
- Attribute hooks no-op without attributes: every reader combines the `IsStudio()` check with a `typeof` check, and `GetAttribute` yields `nil` when nothing is set — nothing defaults on (`DataService.luau:321`; `ActivityService.luau:56`; `MeteorService.luau:207`; `MonetizationService.luau:100-103`; `DailyService.luau:43-44`). The two FX switches are `== false` tests, so absence means effects *on* (`LandingFXController.luau:1607`; `MeteorFXController.luau:78`).
- The client-callable dev remotes return immediately outside Studio (`MeteorService.luau:739`; `RefineryService.luau:277`).
- Chat commands gate per trigger via `Admins.can` (`Main.server.luau:207`), and the live-useful half (`/give`, `/giveall`) is add-only (`AdminGive.luau:148-152`, `:159-161`).
- `DevProduct` never fabricates a Marketplace receipt — it returns `false, "DevProduct only works in Studio."` outside Studio and otherwise reuses the real `_grantProduct` + `Save` path (`MonetizationService.luau:357-377`).

## During Play (command bar / execute_luau)

- `execute_luau` runs with its **own** require and Knit instances, so `Knit.GetService` fails there; drive the real game through remotes from the Client datamodel and read server state via `ServerStorage.DevGrant:Invoke(player)`, which returns a *copy* of the profile (`CLAUDE.md:53`). Long synchronous calls freeze Studio and time out — run loops in `task.spawn` with `task.wait()` and poll an attribute (`CLAUDE.md:52`).
- Isolated runs: set `ServerStorage.DevMemoryStore = true` in Edit **before** starting Play (profiles and leaderboards then never touch DataStores — `DataService.luau:319-323`, `LeaderboardService.luau:140-147`) and clear it in Edit before saving the place (`README.md:15`, `CLAUDE.md:13`). An unpublished place falls back to memory anyway when the probe throws (`DataService.luau:340-343`; `README.md:208` — which also means the tutorial restarts every session).
- Combining hooks is the intended workflow: `DevMemoryStore` first, then `DevMeteorType` + `DevFakeTiers` for a guaranteed Crystal sized for several players (`DataService.luau:321`; `MeteorService.luau:205-209`; `ActivityService.luau:55-61`), then `DevGrant:Invoke(p, 10e6)` to reach the rebirth screen (`README.md:215`; `Main.server.luau:52-54`).

## Where to read next

- Wiring these hooks into Knit: [architecture.md](architecture.md) (Knit wiring; the Notice signal they reply through).
- What `DevProduct` / `DevPasses` actually grant: [monetization.md](monetization.md).
- What the `DevGrant` copy contains: [profile-schema.md](profile-schema.md).
- Running the specs (README "Working on it" step 3, the testing half of that section): the testing guide, landing in this wave.
- The `Map_Redesign` staging roots behind `DevWorldMap`: the map & world guide, landing in wave 3.
