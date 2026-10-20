# 02 — Client UX, UI, first-time user experience

Auditor: client subagent (read-only), spot-checked by the lead.
- **B1 confirmed:** `MeteorHUD` has no DisplayOrder (0), while menus are at 20–100.
- **B2 confirmed in Studio:** `Workspace.Map.TownSquare` exists and `TradingPost` is nil.
- **B11 sized:** 124 debris rocks are on the map.

Scope: `src/client/**`, `src/loading/**`, the `*Layout` modules and `Config/Hud*`.

**Headline:** the tutorial can't soft-lock, every menu can be closed, and every purchase prompt guards `Id = 0`. The
problems are feedback and polish: purchase results are invisible while a menu is open; the copy points at a building
that isn't on the map; the 2x passes aren't in the Store; console controls are weak; and settings aren't saved.

| ID | Sev | Area | Where | Finding | Fix | Conf. |
|---|---|---|---|---|---|---|
| B1 | **P1** | Feedback / payer UX | `HUDController.luau:368-413` (`MeteorHUD`, DisplayOrder 0); menus 20–100; `StoreController.luau:239, 304` | Every HUD toast draws **under** every open menu. Store purchase notices (`MonetizationService.Notice`), "Use credit" refusals, Daily notices and the Hatch equip failure only toast, at top-centre where the 680 px Store panel covers it. A payer buying shards or cash in the Store sees no confirmation. | Put toasts in their own ScreenGui with DisplayOrder ≥ 110, or echo notices into the Store subtitle or card status as Shop, Pets and Rebirth do. | high |
| B2 | **P1** | Core-loop clarity | `Config/Loading.luau:36`, `NativeWelcomeBack.luau:28`, `RefineryController.luau:117, 314`; `EconomyService.luau:109` | Loading tip, welcome-back, refinery claim message and footer all say "sell them at the **Trading Post**", and **the live map has no Trading Post** (verified). Selling is from the HUD. | Replace all four strings with "Tap SELL on your HUD". | high |
| B3 | **P1** | Payer UX | `Config/Store.luau:22-26`, `OfferController.luau:154-177` | **2x Ore and 2x Cash**, the flagship passes, are not in the Store. They're sold only by floating offer icons that hide whenever a panel is open, on layouts without an INDEX slot, and when they would overlap something. The OreRush card even says "You own 2x Ore" for a pass the Store never shows. | Add both to the PASSES section and keep the icons as a second entry. Update `StoreLayout` and `Purchases` specs. *May be an owner placement choice; confirm.* | high |
| B4 | P1 (console) | Gamepad | No `GuiService.SelectedObject` anywhere; Dimmers default `Selectable = true` (`MenuTheme:102`, `NativeUI:72`, `Shop:65`, `IntroController:100`) | Opening a menu leaves selection on a nav tile that `covered()` then disables. Re-entering selection mode can land on the Dimmer, where A closes the menu. The first-join Intro focuses nothing and ignores ButtonB. | Select the primary button on open; `Selectable = false` on Dimmers; ButtonB dismisses the Intro. | medium (needs a pad) |
| B5 | P2 | Settings | `NativeHudMenus.luau:17-24, 126, 134` | Music, SFX, Reduce effects, Camera shake, Show guide and Event tips are client attributes only and never saved. They reset every join. | Add `settings` to the profile (bump schema + migration + RebirthReset), sync via State and a remote. | high |
| B6 | P2 | Hatch | `HatchController.luau:163, 276-283` | EQUIP stays enabled with all slots full; it ignores `PetService:Equip`'s false return and paints "EQUIPPED". The server's notice is hidden under Hatch (B1). | Use the result; show "SLOTS FULL" when full. | high |
| B7 | P2 | Payer UX | `RebirthController.luau:117, 179-181`, `RebirthService.luau:51` | A paid Keep Everything credit is spent by **one tap** on KEEP with no confirm, and the **normal** REBIRTH button also spends it automatically (server sets `keepAll` whenever credit > 0), while still reading "REBIRTH · $cost". | Two-press arm on the credit path; make spending the credit an explicit choice, or relabel the normal button "USES 1 KEEP CREDIT". | high |
| B8 | P2 | Store polish | `StoreController.luau:31, 138, 142`; `Monetization.luau:84, 132, 139` | Off-sale (Id 0) items render as dead "NOT ON SALE YET" cards: Offline Hours+, Streak Shield, Tip Jar. The SUPPORT section is just one dead card. Offers and EVOLVE NOW already hide Id 0. | Skip Id-0 cards; hide empty sections. | high |
| B9 | P2 | Tutorial | `TutorialController.luau:263, 295-297, 501-507`, `ExactNavButton.luau:139-143` | The pointing hand (DisplayOrder 30) keeps pulsing over Store, Index or Rebirth during the SELL and UPGRADE steps, at a nav tile hidden by `covered()` (which leaves `Visible` true). | Also require `Interactable`; hide the pointer while any menu flag is set. | high |
| B10 | P2 | Notifications | `HUDController.luau:171-185, 498` | One toast slot, newest wins, 2.5 s. Sales, level-ups, pet levels, crumbs, "New mineral", "Evolved" and purchase notices overwrite each other during a meteor. | Queue with a minimum show time, or stack 2–3 lines. | high |
| B11 | P2 | Client perf | `LandingFXController.luau:146, 1649`; `FieldFXController.luau:31-56, 124-131` | "Reduce effects" is ignored by the two heaviest FX systems. FieldFX gives **every one of the 124 debris rocks** a PointLight and two emitters (≈124 lights and 248 emitters), with no distance culling and a per-frame Heartbeat that rewrites every light. | Honour `ReduceEffects`; animate only rocks within ~150 studs. | medium (size measured, cost not) |
| B12 | P2 | Flow | `NativeWelcomeBack.luau:55-57`, `DailyController.luau:20, 197`, `ExactNavButton.luau:9` | Welcome Back sets no `*Open` flag, so Daily pops on top of it, nav tiles stay live, and one Escape closes both. | Set `WelcomeBackOpen`; add it to the blocker lists. | high |
| B13 | P2 | Client perf | `Config/Net.luau:9` (0.2 s), `ShopController:391`, `PetsController:424`, `IndexController:220-222`, `StoreController:303` | Closed menus fully re-render on every State flush (5 Hz while mining): every pet card, every mineral card, rich text rebuilt. | Skip while closed and render on open (dirty flag). | medium |
| B14 | P3 | Consistency | `MiningController:61`, `MobileControlsController:66-73`, `RefineryController:24`, `ExactNavButton:9`, `NativeHudMenus:25-26` | Five different "a menu is open" lists. MiningController misses Pets, Daily, Codes, Perks and OreFields, so holding mine keeps swinging inside Pets. | One shared `MenuFlags` list. | high |
| B15 | P3 | Visual | `ExactNavButton:49-53, 142-143`, `PetsController:54, 387` | Nav ReadyBadge dots float over open menus (the Pets badge at DisplayOrder 30). | Hide the badge in `covered()`. | med-high |
| B16 | P3 | Payer UX | `PetsController.luau:142, 361, 407` | Pets shows the **Config** Robux price, not the live one, and the pass prompt isn't pcall'd. | `RobuxPrice.get` + pcall. | high |
| B17 | P3 | Polish | `ShopController:98`, `PetsController:91` | Old notices ("Evolved.", "Slots full") reappear when a menu reopens. | Clear on close. | high |
| B18 | P3 | Input | `NativeUI.luau:202-204` (Codes uses it) | Escape while typing a code closes the Codes menu. | Check `GetFocusedTextBox()` in `bindOpen`. | high |
| B19 | P3 | Touch | `NativeHudMenus.luau:53` | Backpack Close is a fixed 32×32 and ignores `Hud.MinTouch`. | Use `HudLayout.closeSize`. | high |
| B20 | P3 | Feedback | `DailyController.luau:153-159` | A failed daily claim shows nothing. | Show the reason. | high |

## New-player timeline (from code)
- **Loading screen:** 1.5 s minimum, 20 s hard cap.
- **Intro:** 5 pages, skippable.
- **First hit:** the player spawns next to the soft Rust Works rocks (`TutorialService:148-160`), so the first meaningful hit comes about 15–35 s after joining.
- **First meteor:** up to 120 s (90 s on a fresh server); the guide points at rocks while waiting.
- **Observed in Play by the lead:** step 3/10 "RUN!" with the meteor banner up about 60 s in (see `04-…` D8).

## Checked and found solid
- **The tutorial can't soft-lock:**
  - Doing a later step completes the earlier ones.
  - Joining mid-event is handled by the crater-radius watcher.
  - Progress is saved, so a rejoin resumes.
  - Skip is always shown.
  - Daily waits for the tutorial.
- **Loading screen:** it has a hard deadline, always sets `LoadingDone`, and removes the default loading screen.
- **Layout marks:** the swaps are correct, and the builder names match what the controllers bind.
- **Purchase prompts:**
  - Every prompt guards Id 0.
  - Owned passes update live.
  - One-off products show OWNED.
  - Rebirth Keep resumes after purchase.
- **Mining input:** works on touch, gamepad and keyboard. The touch MINE button only shows for touch input.
- **Closing menus:** every menu has Close, the Dimmer and Escape/ButtonB.
- **Rebirth:** a two-press arm.
- **Disabled reasons:** shown on Refinery and Perks.
- **No per-flush instance churn:** `MenuTheme` reuses gradients and strokes.

Not checked: MenuSkin's colour remap, `.rbxmx` beyond bound names, `HudLayout` phone geometry (covered by specs).
B4, B11 and B13 need a device or MicroProfiler check.
