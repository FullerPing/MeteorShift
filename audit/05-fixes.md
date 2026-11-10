# 05 — Fixes applied (2026-10-20)

Branch `audit/2026-10-20`. Each line names the audit finding it closes. "Player-visible" marks behaviour
or balance changes players will notice. Spec suite after the fixes: see the bottom of this file.

## Save schema: v13
- Profile `version = 13`. v12 was skipped on purpose: an unreleased trial build saved v12 profiles with a
  `trialFlag` key, and v13 removes it. New keys:
  - `paidShards`: the Robux-bought part of `shards`.
  - `settings`: saved Settings toggles.
  - `credits.petMax`: a banked Pet Max.
- Files: `ProfileTemplate.luau`, `DataService.luau` (migration and clean-up), `tests/ProfileTemplate.spec`.
- Closes D5.
- **Your working tree still has the old uncommitted trialFlag v12 edits** in `ProfileTemplate`, `RebirthReset`, `DataService` and `RebirthReset.spec`. Discard them before merging this branch.
- DataService: a session lock is stale after 5 min (5 × autosave) instead of 30 min, so a crashed server no longer locks its players out for half an hour (D4).

## Payer safety and monetization

**Paid random items (C1).** New `Shared.ShardWallet` tracks which shards were bought with Robux. It covers these sources:
- shard packs,
- tier-up shard refunds,
- the repeat-PetSlot refund,
- the Starter Pack shard fallback.

Hatching works like this:
- `PetService:Hatch` asks `PlayerPolicyService:CanUsePaidRandomItems`. Where paid random items are restricted, eggs only take earned shards, and the player gets a clear notice.
- Eggs spend earned shards first.
- Perks and evolves spend bought shards first (`PerkService`, `ShopService`), so earned shards stay free for eggs.

Shards bought before v13 count as earned.

**Pet Max with nothing to level (D1/C3).** It is banked as `credits.petMax`, and the next pet put out below max goes straight to max level (`Purchases.applyPetMaxCredit`, `PetService:_putOut`). The Store card shows UNAVAILABLE ("Equip a pet below level 10 first") or "Banked: n".

**Repeat one-off purchases (D3/C2).**
- A second `PetSlot` refunds 175 Core Shards (`Config.Monetization.RepeatRefundShards`).
- `StarterPack` still grants again; the buyer paid, so they get the content.

**Back-to-back receipts (D2).** A receipt that arrives while the same player's previous one is saving now waits up to 10 s instead of returning `NotProcessedYet`.

**Purchase feedback (B1).**
- Toasts live in their own `HudToasts` ScreenGui at DisplayOrder 110, so purchase notices show over open menus.
- The Store also echoes notices in its subtitle.

**Boosts that did nothing (C4).** **Player-visible:** while Overclock runs, bars also sell for **+50%** (`Monetization.Overclock.BarBonus`). This applies to Mini Overclock and the Starter Pack's overclock too. Before, Overclock did nothing once mining, not the line, limited income.

**VIP (C5).** **Player-visible:** VIP is now **+25%** bar value (was +10%). *The price itself is set on the Creator Dashboard: consider VIP 99 R$.*

**Store placement (B3).** **Player-visible:** 2x Cash and 2x Ore are now in the Store's PASSES section. The HUD offer icons still sell them.

**Off-sale items (B8).** Store cards with Id = 0 are hidden, along with any section left empty.

**Cash packs (C11).** **Player-visible:** the caps change.

| Pack | Was | Now |
|---|---|---|
| Pocket Change | 30% of next rebirth cost | 25% |
| Cash Bundle | 80% of next rebirth cost | 90% |

Three Pockets no longer beat one Bundle, and a Bundle still never buys a whole rebirth.

**Starter Pack (C12).** With no pet equipped, the Starter Pack pays 30 Core Shards (one Meteor Egg) instead of pet XP nobody receives.

**Keep Everything (B7/C24).**
- A paid Keep Everything credit is only spent on purpose: `RebirthService:Rebirth(useKeep)`.
- The normal REBIRTH button never spends it.
- KEEP takes two presses.

**Refunded passes (A16).** Pass pets are taken back when Roblox reports the pass as not owned. A failed ownership lookup never removes one.

**Income quotes (C16).** Expected-income quotes (cash packs, offline crew, daily, codes, field rocks) leave out timed boosts, so buying an Overclock or Ore Rush first can't inflate them.

## Economy, pacing, retention

**Offline income (C8).** **Player-visible:**
- Offline time now pays a **colony crew** on top of the hopper stock: 25% of expected income for the capped time away.
- It is capped at 50% of the next rebirth's cost and needs 15 min away (`Config.Home.OfflineCrewShare` / `OfflineCeilingShare` / `OfflineMinAway`).
- This makes Offline Training and the future Offline Hours+ pass worth having.

**Welcome Back (C15).** The Welcome Back roll also needs 15 min away, so rejoining no longer rerolls it.

**Daily streak (C6).** **Player-visible:** each day of the streak raises the daily cash ceiling: ×1, 1.5, 2, 2.5, 3.5, 5, 7.5 (`Config.Daily.Days[].CeilingMult`). Day 7 is now visibly bigger than day 1 at every rank.

**Head Start (C7).** **Player-visible:** the perk is reworked. It now gives starting cash after a rebirth: 3 / 6 / 10 / 15% of the next rebirth's cost. Before, it floored gear tiers that survive a rebirth anyway, so it did nothing.

**Legacy ranks (C9/C10).** **Player-visible:**
- The first Legacy cost steps up ×4.7 (`Legacy.FirstStep`), then grows ×2.05 per rank (was ×2.3).
- Simulated laps now run from about 20 min at rank 17 to 38 min at rank 60. Before, the lap halved at rank 17 and then compounded to about 3 h by rank 41.

**Miner pets (C14).** **Player-visible:** the miner role cap rises from 1.0 to 1.5, so Drillbot or Meteor Drake add to a maxed Solar Phoenix.

**Fractional stock (A13).** Backpack, hopper and collection-post capacities are whole numbers, so ore and bars no longer go fractional.

**Debris pay (A4).** **Player-visible:** debris cash scales by how much of the rock's HP the breaker's pickaxe actually had to chew through. A veteran one-shotting newcomer-sized rocks now earns proportionally less.

**Core rewards (A3).** **Player-visible:** you need at least 2% of core contribution for the shard floor, the bonus pool head count and the top three. A lone hitter always qualifies.

**Golden Node (A10).** **Player-visible:** an assist needs at least 5% of the node's Mining Power. The breaker is always paid.

**Supply Crates (A12).** One crate per level gained (several levels at once now open several crates).

**Stats (A14).** `coresCracked` only counts real cracks.

## Robustness, security, scaling
- **Background loops (A1/A2).** New `Lib.SafeLoop`, with every background loop's body protected:
  - the refinery tick (per player),
  - the Call a Meteor availability check,
  - contribution, debris reroll and eject,
  - the Crown eject,
  - the tutorial crater check,
  - the leaderboard,
  - the world boundary,
  - the daily publish,
  - telemetry.
- **Swing speed (A7).** A token bucket (`RequestGate.pace`) holds the long-run swing rate to 1/Swing. A single early swing (20%) is still accepted.
- **Meteor sizing (A9).** **Player-visible:** only validated swings count as "active"; pings and joiners no longer inflate meteor HP. A lobby that only waited may get a smaller meteor for the first ~10 s.
- **Core lock (A11).** A crust-bonus error can no longer leave the core locked; bonuses run last, inside a pcall.
- **Field gates (A15).** Gated fields fail closed when the map has no `Gates` folder.
- **`/give` (A17).** Amounts are capped at 1e30.
- **Leaks (A18).** Leaderboard `saved` entries and per-player and per-character connections are cleared on leave (`LeaderboardService`, `ShopService`, `TutorialService`, `PlayerStateService`).
- **Pet effects traffic (A5).** Pet "Working" effects go only to players within 150 studs instead of `FireAll`.

## Client UX and UI (B1–B20)
- **Menus:**
  - New `src/client/MenuFlags.luau`: one list of menu-open flags, used by Mining, MobileControls, Refinery, ExactNavButton, NativeHudMenus, Daily, Tutorial, CustomHud, FieldTravel, FastWalk and Offer (B14).
  - Welcome Back sets `WelcomeBackOpen` (B12).
  - Escape is ignored while typing (B18).
- **Wording:** "Trading Post" copy now says to tap SELL on the HUD (B2).
- **Gamepad (B4):**
  - Dimmers aren't selectable.
  - Selection jumps to the open menu's Close button, and is cleared on close.
  - The Intro takes ButtonB, and NEXT has focus.
- **Settings are saved (B5):** the client applies `state.settings` once and calls `PlayerStateService:SetSetting`.
- **Hatch (B6):** EQUIP uses the server result and shows SLOTS FULL.
- **Tutorial pointer (B9):** it hides while a menu is open.
- **Toasts (B10):** they queue (minimum 1.2 s each, de-duplicated).
- **Effects (B11):**
  - ReduceEffects is honoured live by LandingFX and FieldFX.
  - FieldFX only animates rocks within 150 studs.
- **Closed menus (B13):** they skip re-renders (Shop, Pets, Index, Store).
- **Visual fixes:**
  - Nav badges hide under menus (B15).
  - The Pets menu shows the live Robux price, and its prompt is pcall'd (B16).
  - Stale notices clear on close (B17).
  - The Backpack close button meets the touch size (B19).
  - Daily shows failed claims (B20).
- **Tutorial copy:** the "RUN!" step has a sub-line (D8).

## Follow-up: Overclock, smoothness, alignment

**Overclock was only 12–20% faster.** Overclock and Mini Overclock doubled the refinery but not the conveyor. The line runs at `min(conveyor, refinery)`, and the conveyor is barely faster than the refinery, so the boost had almost no effect.

- `Lib/Refining` now applies the speed to the whole line, so it is a true ×2.
- `tests/Refining.spec` used to pin the old behaviour and now pins the fix.

**The Foundry didn't show it.** The Foundry card now reads "OVERCLOCK ×2 speed, +50% bar value · m:ss left" in gold, and its rate shows ⚡. The countdown stays current while the line is idle (`RefineryService`).

**Smoothness.**

- **Native menus** now slide up 28 px and fade their dimmer in when they open, instead of snapping on. Closing stays instant. This is in `NativeUI.animateOpen`, so every menu built through `NativeUI.get` gets it.
  - Only the position is animated. A scale tween would re-pin every label's text size each frame through `FixedTextSize`, and that stepping text is a big part of why the UI felt janky.
- **Chunky buttons** lift 1 px on hover and sink 3 px into their lip while held (`NativeUI.pressable`).
- **HUD side tiles** lift 2 px on hover and dip 3 px while held (`ExactNavButton`).
- All of this is off with Reduce Effects.

**Alignment and balance.** I measured these in Play on a virtual 1920×1080 screen.

- **Gear Shop and Pets** were bottom-heavy: about 20 px of margin at the top but 5 px at the bottom. Everything now sits 6 px higher, giving about 14 px top and 11 px bottom.
  - The Shop's preview well is 187 px tall, to match the stats card beside it.
  - The Pets hint is as tall as its action button, so both columns end on one line.
- **Rebirth:**
  - The side gaps were 10/2/6/8 px and are now 8/4/6/8.
  - Both columns end at y=456.
  - The wallet sits on the same line and right edge (698) as the Shop's and Pets' wallets.
- **Refinery:** the right card ended 1 px short of the order card. The rounding remainder now goes into the gap.
- **HUD (desktop):**
  - The Production card sat 2 px below the wallet and backpack. Its `Bottom` margin is now 18, like theirs.
  - The right tile stack used a margin that shrank with the tiles. It now mirrors the left column.
  - Both are pinned in `tests/HudLayout.spec`.

## Not done (needs the owner, a device, or a bigger design pass)
- **C17:** badges. All 11 badge ids are 0: create them in Creator Hub and paste the ids into `Config/Badges.luau`.
- **Dashboard prices:** VIP (C5), and the T4→T5 tier-up price mismatch, pickaxe 49 vs backpack 39 (C23). These are Creator Dashboard values, and the specs pin the current ones.
- **A6:** splitting the State snapshot into hot and cold parts is a larger refactor of the client contract. Measure first.
- **A8:** a server-side speed check for teleporting. It's typical for the genre and optional.
- **C13:** a repeatable late-game shard sink. **C25:** an Alien Index page. **C18:** an auto-collect pass. **C19:** a stronger Call a Meteor. All four need new content or design.
- **C22:** the Drill Pick lands exactly on the 8-minute edge of its spec window. The fit still passes, so I didn't re-fit prices blind.
- **D6:** receipts are kept forever on purpose (Config documents why). Not a bug.
- **Play-mode checks still needed:**
  - toasts over open menus,
  - gamepad selection,
  - the ReadyBadge position,
  - the KEEP button text fit,
  - the Store rebuilding with the new pass cards,
  - FieldFX and LandingFX cost on low-end devices.
