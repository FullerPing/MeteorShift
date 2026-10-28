# Store art plan: 5 thumbnails, the icon and the loading screen

> **Status (9 Oct 2026):** the art was built as 2D code-drawn vector art, **not Blender** (the owner vetoed Blender). See `tools/store-art/README.md`. The Blender sections of this brief (3.1 to 3.3) are superseded; an earlier Blender-made set is archived in `assets/marketing/v2/archive-blender/`.


For the agent that builds them. Game: **Craterworks: Meteor Mining** (Roblox place 113476105600560, repo `MeteorShift`). Read sections 0 to 3 first, because every deliverable depends on them. Sections 4 to 10 are one self-contained brief per piece. Section 11 is the loading screen (art plus Luau code). Section 12 is the order of work and the acceptance checklist.

**What is wrong with the existing marketing art:** `assets/marketing/*` (Oct 4) shows a flat teal/charcoal dusk vector scene with a dark meteor. The game has since become a **bright glossy cartoon simulator** (blue sky, cream plaza, green lawn, Crater Isle, sky islands, pets, ink-outlined HUD). The old art no longer matches and must not be reused as-is. Keep the old files, because they are the archive. Write new work to `assets/marketing/v2/`.

---

## 0. Deliverables

All paths under `assets/marketing/v2/`. Nothing is uploaded to Roblox by you: the owner uploads icon and thumbnails in Creator Hub. Do not commit or publish unless asked.

| # | File | Size | Purpose |
|---|---|---|---|
| I | `icon-512.png` (+ `icon-1024-master.png`) | 512×512 and 1024×1024 | Experience icon |
| T1 | `thumb-1-meteor-impact.png` | 1920×1080 | First thumbnail: logo plus the giant meteor and the miner |
| T2 | `thumb-2-pickaxe-power.png` | 1920×1080 | Three-panel gear progression (x1 / x5 / x20) |
| T3 | `thumb-3-hatch-legendary.png` | 1920×1080 | Egg, red arrow, legendary pet, "1 IN 200" |
| T4 | `thumb-4-rebirth.png` | 1920×1080 | Before/after split, "x5" |
| T5 | `thumb-5-boss-meteor.png` | 1920×1080 | Co-op Alien boss meteor |
| L | `loading/loading-bg.png`, `loading/wordmark.png`, `loading/cloud.png`, `loading/trail.png` | see section 11 | Loading screen art |
| L code | `src/loading/LoadingScreen.client.luau`, `src/shared/LoadingProgress.luau`, `tests/LoadingProgress.spec.luau`, `Config/Loading.luau`, `default.project.json` edit | | Loading screen |
| W | `wordmark.png`, `wordmark.svg` (if the vector route works) | 2400 px wide, transparent | The shared logo |
| Proof | `preview/contact-sheet.png`, `preview/small-sizes.png` | | For review, not for upload |

Roblox limits to check against the current docs before finishing: icon is square, 512×512 recommended (never smaller than 256). Thumbnails are 16:9, 1920×1080 recommended (never smaller than 1280×720), PNG or JPG, up to 10 per experience (we make 5). Keep each file under 5 MB. Do not bake rounded corners or borders into the icon, because Roblox masks it.

Roblox moderation: no Roblox logo, no Robux symbol, no "FREE", no sale copy, no fake stats or invented UI, no photographic or real-person likeness. Numbers and odds on the thumbnails are allowed (section 2.4) only when they are true to the config at build time.

---

## 1. Facts about the game the art must get right

- **Premise:** every few minutes a meteor slams into the crater in the middle of town. The whole server rushes to crack it together. Between meteors you mine debris rocks in four ore fields. Ore goes to the Foundry (the refinery), bars are claimed and sold at the Trading Post for cash, cash and shards buy gear, Rebirth multiplies income. Pets are hatched from eggs with Core Shards earned in play (no paid randomness). Never imply pay-to-win.
- **The four meteor types and their colours** (`src/shared/Config/Meteor.luau`):

| Type | Crust | Glow | Core |
|---|---|---|---|
| Iron | #B87654 / #CC8A62 / #9C6248 | #FF963C | #D74E18 |
| Ice | pale blue-white | #78ECFF | cyan |
| Crystal | #9E6CCC / #B67EDC / #845AB4 | #FF56E8, ore #FF7AD6 | #CD32BE |
| Alien (boss) | #3EB07E / #56CC94 / #30966E | #6EFFA0 | #46EB78 |

- **Ore fields** (their colours tint the rocks): Rust Works #FF7C38, Frost Yard #6ED4FF, Violet Quarry #B874FF, Sulfur Ridge #FFCC40.
- **Pickaxe tiers (1 to 8):** Basic (grey), Steel, Drill Pick (orange), Plasma Pick (cyan), Meteorite Pick (red-orange), Nova Pick (violet), Singularity Pick (near-black with purple), Cosmic Pick (pink). Backpacks go t1 to t8 as well. Models are in `blender/equipment/pickaxe_t1..t8` and `backpack_t1..t8`.
- **Pets (14):** common Pebble Pup, Scrap Sparrow; uncommon Pack Mule, Spark Hare; rare Jet Wisp, Coin Magpie, Cargo Mole, Granite Golem; epic Crystal Stag, Lode Wyrm, Aurora Owl; legendary Meteor Drake; premium Drillbot, Solar Phoenix. Eggs: Meteor Egg, Crystal Egg, Aurora Egg (rebirth-gated). Models: `blender/pets/<id>.blend|fbx|png` and `<id>_lv10.*` (the max-level look, which has extras; use these for the thumbnails). Eggs: `blender/eggs/egg_*.blend`.
- **Rarity colours** (Config.Pets): common #B0BAC6, uncommon #78DC8C, rare #5AAAFF, epic #BE78FF, legendary #FFBE3C, premium #FF6EBE.
- **The world, as it looks now (match this):** bright blue sky with big soft cartoon clouds. Cream, stud-textured plaza with a yellow ring road around a dark blue-grey crater bowl. Green lawn. A cream rampart with a navy base band, rounded merlons and four round corner towers. Beyond it a turquoise lagoon, palm islands, two red-and-white lighthouses, rounded teal and blue-violet mountain ranges, **Meteor Peak** (a glowing volcano with a lava lake, neon crystals and a smoke plume straight north) and three floating **sky islands** with crystals, a tree and a waterfall. Landmarks inside: Foundry (refinery with sawtooth roof and tall striped chimney), Gear Hall (blacksmith forge with an anvil), Hatchery (egg garden with a giant egg), Trading Post (striped awning), Rebirth Monument (portal shrine), Meteor Watch (observatory).
- **The player:** blocky Roblox avatar in warm orange and gold armour with a dark-red plume, dark boots, a backpack and a pickaxe. This is the "Craterworks Miner" mascot. Use this costume on every character in the art; for secondary characters only change the armour hue (blue #2E80F0, violet #8C32E8, green #32C41E).
- **Game HUD look** (`src/client/Cartoon.luau`): FredokaOne font, ink outline `#0E1834`, vertical gradients with a darker lip underneath, soft top shine, diagonal gloss stripes, a faint stud texture. The marketing art must feel like the same product.

---

## 2. Style bible (applies to every piece)

### 2.1 Palette (from `Cartoon.Palette`, top / bottom / lip)
| Role | Top | Bottom | Lip |
|---|---|---|---|
| Blue (sky UI, ribbons) | #56BAFF | #1E68E8 | #103A96 |
| Deep blue | #388AF0 | #1648BE | #0C2870 |
| Gold | #FFF078 | #FFB21E | #B06806 |
| Orange | #FFD250 | #FF801A | #AA4608 |
| Green | #B2FF4A | #32C41E | #166E12 |
| Purple | #D480FF | #8C32E8 | #541696 |
| Red | #FF6876 | #E21A38 | #8C0A1E |
| White | #FFFFFF | #D6EAFC | #789CD2 |

Ink outline **#0E1834**. Text-on-white blue **#1846A0**. Ice #C4F2FF. Lime #B0FF5C.
Sky: #3E9BFF at the top to #BFEBFF at the horizon. Clouds #FFFFFF with a lavender underside #EEECFC.

### 2.2 Look rules
1. **Chunky and rounded.** Bevelled shapes, no thin details, no realistic textures. Three tones per colour (light top, body, dark base), flat colours, no noise.
2. **Ink outlines on everything that matters:** about 0.8 to 1.0% of image height on the hero and the logo, half that on background objects. Colour is always #0E1834, never pure black.
3. **Glow comes from compositing, not from the renderer.** Render clean, then add glow layers in the composite: gaussian blur of the bright pixels, added with screen blending, radius 2 to 4% of image height. Neon pieces (cores, lava, crystals, lamps) read as flat bright colour plus that bloom.
4. **Lighting:** one warm key from the upper left (#FFF1D6), a soft blue fill (#8EC8FF) from the right, a rim light on the hero's edge nearest the glow. Soft contact shadows only, in a dark blue (#1A2A5A at 35%), never grey or black.
5. **Saturated and bright.** The daytime sky stays in every shot except where the shot is intentionally lit by a meteor. Keep value contrast: the hero is the lightest or the most saturated thing in the frame, the background is mid-value and slightly hazed (blend to #BFEBFF by 20 to 35% with distance).
6. **Depth cues** (cheap and effective): atmospheric haze, a vignette (corners down 15%), a light-ray fan behind the hero, 12 to 30 floating sparkles of mixed sizes (4-point stars in white and gold with an ink outline on the big ones), flying chips and coins.
7. **Characters:** blocky, front-lit, big readable faces (two dot eyes, simple smile), heads about 22% of body height for charm. No guns, enemies, violence or blood.
8. **No HUD or menus in the art.** The only UI-like shapes are the callouts in section 2.4 (arrows, ribbons, the HATCH pill). No logos of other games or platforms.

### 2.3 The wordmark (build once, reuse everywhere)
Font: **Fredoka One** (`assets/marketing/vector-art/fonts/FredokaOne-Regular.ttf`, SIL OFL, same family as the HUD). Text: `CRATERWORKS`, plus the subtitle `METEOR MINING` on a ribbon.

Layers, bottom to top (use cap height `H` as the unit):
1. Soft drop shadow: ink at 40%, blur 0.12 H, offset (0, 0.22 H).
2. Outer ink stroke, `#0E1834`, width 0.16 H, round joins.
3. Lip: the same text offset down by 0.09 H, fill `#AA4608` (word `WORKS`) or `#789CD2` (word `CRATER`), with a 0.10 H ink stroke.
4. Face: `CRATER` filled with a vertical gradient `#FFFFFF` to `#C4F2FF`. `WORKS` filled with `#FFF078` to `#FFB21E`. Both with a 0.06 H ink stroke around the face.
5. Top shine: a clipped half-height white shape at 28% alpha across the upper half of each letter, plus a 0.03 H white highlight line just inside the top edge.
6. Letter personality: each letter's baseline offset by a deterministic ±0.03 H, rotation ±2°, the whole word rotated -3°. Add a 4-point gold sparkle star at the top right of the final S (ink outline).
7. **Subtitle ribbon** `METEOR MINING`: swallow-tail ribbon, blue gradient `#56BAFF` to `#1E68E8`, 0.08 H ink outline, a darker lip, width about 62% of the word width, centred, overlapping the bottom of `CRATERWORKS` by 12%, rotated -3°. Text white `#FFFFFF`, Fredoka One, 0.045 H ink stroke, letter-spacing +6%.

Deliver `wordmark.png` (transparent, 2400 px wide, full lockup) and `wordmark-only.png` (no ribbon). Build route (pick the one that works): (a) the existing Node pipeline in `tools/build-craftworks-molten.cjs` (opentype + sharp, outlined text in an SVG, see its `label()` helper; the sharp path is hard-coded to the Codex runtime and `.tmp/craterworks-opentype.cjs` exists), or (b) Pillow: `ImageFont.truetype(..., size)`, draw text with `stroke_width` for the stacked outlines, and composite the gradient with a mask. Pillow 11.3 and numpy 2.0 are installed (`fontTools` is not). Either way, view the result at 25% size and check that `CRATER` and `WORKS` are distinct and the ribbon is readable.

### 2.4 Reference style (the owner's target)
The owner supplied a screenshot of top Roblox simulator thumbnails (Heroes RNG, Sky Clickers, Pet Dice, "+1 Power Per Click", Dig For Eggs, High Tide Heist and similar) and wants the thumbnails to look like these, adapted to Craterworks. What they have in common, and what we copy:
1. **One giant hero** (a pet, a weapon, a building or an egg) at 55 to 70% of the frame. Almost no small detail.
2. **Big numbers as the hook:** "1 IN 10,000,000", "+999T", "x100". Cap height at least 170 px, white or gold, thick ink outline, a lip and a drop shadow, a slight tilt. In our art every number must be **true to the config** (see each thumbnail) and traced in the README.
3. **Before and after:** a red arrow from a plain thing to an amazing thing, or 2 to 3 split panels with escalating colours (blue, orange, purple). Panels have bold white gutters.
4. **Callout ribbons and a button pill** (`LEGENDARY!`, `BOSS METEOR!`, a green `HATCH!` pill), cap 52 to 72 px, ink outlined. Never "SECRET", "NEW", "UPDATE" or "FREE".
5. **Radiating rays and sparkles** behind pets and rare things. **Saturation 85 to 100%**, glossy 3D render look with soft bloom, bright and clean, never dark.
6. **Roblox-style avatar** facing three-quarters, big and readable, cropped by the frame edge for presence.
7. **Red arrow style:** `#E21A38` face, 0.05H white outline, ink outer outline, a bevel and a lip.
Do not invent figures: no prices, cash totals, rebirth costs or fake rarities.

---

## 3. Production pipeline

The key art is a **3D render in Blender plus a 2D composite**. This keeps the pets, equipment, eggs and props identical to the real game, because those models already exist as Blender sources of the in-game meshes.

### 3.1 Tools that are already here
- **Blender 5.2** at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (not on PATH; call it by full path, `blender.exe -b -P script.py` for headless).
- **The asset library** in `blender/`: `.blend` and `.fbx` per asset, a 512 px preview PNG, `palette.png` (a shared 256 px palette texture), `manifest.json`, `tools/blender-assets/assetlib.py` (the authoring helper, `API.md` documents it) and `review/*.png` contact sheets. Conventions: 1 Blender unit = 1 stud, Z up, front -Y, tintable surfaces are neutral white in the files (colour them yourself), neon surfaces have no texture.
- **Python:** Pillow 11.3, numpy 2.0. No `fontTools`.
- **Node + sharp + opentype** (see 2.3).
- **The Roblox Studio MCP** (deferred tools; load with ToolSearch) for the loading screen work and for the optional in-engine reference screenshots.

### 3.2 Files to create
```
tools/key-art/
  common.py        palette dict (hex), toon_material(name, hex), ink_shell(obj, thickness),
                   sun_and_fill(), world_sky(top, bottom), camera(loc, target, lens), render(path, w, h, samples)
  miner.py         procedural Craterworks Miner (R15 proportions, orange/gold armour), pose(name)
  isle.py          the Crater Isle diorama builder (crater, ring road, rampart, hills, sea, Meteor Peak, sky islands, clouds)
  foundry.py       a chunky Foundry building (the refinery) built from the in-game description
  shots.py         one function per shot: t1() .. t5(), icon(); each renders PNG layers to tools/key-art/out/<shot>/*.png
  composite.py     Pillow compositing: layer stacking, bloom, vignette, sparkles, wordmark, text; writes the final PNGs
  smalltest.py     builds preview/small-sizes.png (see 3.4)
  README.md        how to rerun everything (Blender command lines, order)
```
Keep outputs of intermediate renders in `tools/key-art/out/` (gitignore not required; they are large, so do not commit them unless asked).

### 3.3 Render recipe (the same for all shots)
- **Engine:** Eevee, 1 sample of motion blur off, soft shadows on, ambient occlusion on, **render at 2× the target** (3840×2160, icon 1024×1024) and downsample with Lanczos in the composite for clean edges.
- **Materials:** `toon_material` = Principled BSDF, roughness 0.55, specular 0.25, base colour from the palette, no textures except the shared `palette.png` already on library meshes. Tintable parts take the colour from section 1 or 2.1.
- **Ink shells:** for every hero mesh, add a duplicate with a Solidify modifier (thickness 0.035 to 0.06 units depending on size, offset +1, flip normals), a flat `#0E1834` emission material, backface culling on. Add the same to terrain pieces at half thickness. This is robust in Eevee and scales with the object.
- **World:** a vertical gradient (section 2.1 sky) as the world colour plus a few big white sphere-clouds placed for composition. A ground haze plane (white, 25% opacity gradient) at the horizon.
- **Camera:** per shot (see sections 5 to 10). Use a 35 to 50 mm lens for hero shots, 28 mm for panoramas. Keep the horizon slightly tilted (2 to 4°) for energy.
- **Render passes you must output per shot** (separate PNGs with alpha): `bg` (sky plus far scenery), `mid` (island and landmarks), `hero` (characters, meteor, pets), `fx` (everything that should glow, on black, for the bloom pass), plus `depth` (a Z pass normalised) if you want depth haze in the composite.
- **Layout guides:** every shot below gives positions as percentages of the 1920×1080 frame. Place objects so the described boxes hold, then check against the list in 3.4.

### 3.4 Composite recipe and the small-size test (do not skip)
Composite order: `bg` then haze (by depth) then `mid` then `hero` then `fx` bloom (screen blend, blur 36 px at 1080p, strength 0.7) then god-rays then sparkles and flying bits then vignette then text and wordmark.

After each final PNG, write the small-size test image: the final at 384×216, 256×144 and for the icon at 150, 96 and 64 px, tiled in one image (`preview/small-sizes.png`) and **look at it**. Pass criteria:
- The hero silhouette is recognisable at 256×144 with the logo or headline text covered.
- Headline text is legible at 384×216: cap height at least 120 px at 1920 wide (24 px at 384 wide).
- Nothing important within 4% of any edge (about 76 px left/right, 43 px top/bottom). Text may sit low, but never closer than 4% to the bottom.
- The five thumbnails side by side use different dominant hues (T1 orange on blue sky, T2 blue / orange / purple panels, T3 gold sunburst, T4 split blue-grey and magenta, T5 lime green), which keeps the carousel varied while the ink outlines and fonts keep it one family. Also view them in a 5-up grid on a dark background (like the reference screenshot) and check that each one pops.

---

## 4. Shared assets to build first (reused by everything)

1. **Wordmark** (2.3).
2. **Craterworks Miner** (`miner.py`): Roblox R15 proportions (head 1.2, torso 2×2×1 studs, limbs 1×2), faces `-Y`. Armour is orange `#FFB24A` / `#FA8028` / `#BA4E1A` on chest, shoulders (big rounded pads), forearm guards and shins, a dark-navy undersuit `#283456`, boots `#161E36`, a gold belt `#FFB21E`. A rounded helmet in the same orange with a teal visor band `#2ED6C4` and a **dark-red plume** `#E21A38` / `#8C0A1E` on top. Face: a skin tone `#F2C69A` face with two `#0E1834` dot eyes and a small smile (draw it on a 256 px texture in Pillow). Carries a **pickaxe** (`blender/equipment/pickaxe_t4`, Plasma Pick, for hero shots; t1 for beginners in T4) and a **backpack** (`backpack_t1` or `_t4`). Poses needed: `swing` (both hands, pickaxe raised high behind the head, front foot forward), `cheer` (one fist up), `carry` (backpack heavy, leaning forward), `idle`.
   Also build recolours: blue, violet and green armour variants for background characters.
3. **Crater Isle diorama** (`isle.py`, the geometry from `tools/map-v2/*.luau` is the reference: the crater is a dark bowl 83 studs in radius, a yellow ring road, a cream plaza, the rampart at ±288 studs, trees as lollipops with three tiers). It does not need to be exact, only to read as the same place: a cream plaza disc, a yellow ring, a blue-grey crater bowl, a green lawn, the rampart with navy base and merlons, round corner towers, rounded hills. Use `blender/props/*` (lamp posts, trees, crates, barrels, banners) and the map heroes (`blender/map/Anvil`, `GiantEgg`, `Trophy`, props `turret`, `fountain`) where helpful.
4. **The Meteor** (use `blender/meteor/meteor_core.blend` and `node_piece_a..d`): assemble 36 crust pieces on the core as the game does (pieces on a sphere, outward-facing, recoloured per type in section 1). Provide an intact **Iron** meteor for T1 and the icon, and a **broken Alien** variant (about 60% of the crust removed, the core exposed) for T5.
5. **Sparkles, chips, coins, stars:** 2D, generate in Pillow: 4-point stars (white and gold, 16 to 120 px, ink outline on the big ones), round glints, rock chips (small hexagons in the ore colours), coins (`blender/items/coin.png`).
6. **Damage numbers** (2D, for T1 and T2): Fredoka One, white with ink outline, gold for crits with a "!" suffix, random small rotation. Exactly the game's look (floating numbers over a node).

---

## 5. THE ICON, 512×512

**Goal:** be recognisable at 150×150 and at 64×64, promise "meteor mining" instantly. No text (the title shows next to the icon; text at this size is unreadable and Roblox crops the corners).

**Composition (1024×1024 master, downsample to 512):**
- **Background:** radial gradient, centre `#56BAFF`, edges `#1E68E8`; 12 faint white light rays (8% alpha) fanning from the meteor; two soft white clouds at the bottom corners (clipped by the edge).
- **Hero: a glossy molten meteor**, diameter 68% of the frame, centred slightly low-left at (46%, 56%). It is a rounded rock with a dark rust crust `#9C6248` / `#B87654` / `#CC8A62` and **bright cracks** (the core glow `#FFB24A` to `#FFF078`), with a small number of big chunky cracks (4 to 5, not a web) and a big soft white specular highlight in the upper left. Ink outline 1.2% of the frame (about 12 px at 1024).
- **Tail:** a fiery streak from the top right into the meteor: gold `#FFF078` core, orange `#FF801A` edge, fading to transparent, about 40% of the frame long, with 6 to 8 embers.
- **Pickaxe:** the Plasma Pick (cyan `#50DCFF` head, orange `#FF801A` handle) crossing diagonally from the lower left to the upper right in front of the meteor, tip biting into the upper-right of the meteor; its head about 28% of the frame. Ink outlines.
- **Impact starburst** at the contact point: an 8-point white-to-gold star about 22% of the frame with a thick ink outline, 5 to 6 flying rock chips and 3 sparkles.
- **Safe zone:** all essential shapes inside the central 88% (Roblox rounds the corners). The meteor plus pickaxe plus burst must read as a single clear silhouette: round plus diagonal plus star.
- **Contrast:** the meteor is the darkest, most saturated mass; the background is bright blue. Keep value separation of at least 30% between the meteor body and the background.
- **Optional B variant** (`icon-512-alt.png`): the same, with the wordmark `CRATERWORKS` on a small ribbon along the bottom (text height 12% of the frame). Deliver it only if A looks empty.

**Checks:** 150 px and 64 px previews; the burst and pickaxe are visible; no tiny details (nothing under 4 px at 150 px); no text; no border.

---

## 6. THUMBNAIL 1: "METEOR IMPACT" (`thumb-1-meteor-impact.png`)

**Role:** the main thumbnail and the one that says what the game is. Same recipe as the reference "Build An Ant Empire" and "High Tide Heist": one giant hero object, a big readable avatar, bright sky, a logo.

**Camera:** low three-quarter, looking slightly up, 35 mm, horizon at 62% height, tilted 3°.

**Layers (boxes are x% by y% of the 1920×1080 frame):**
1. **Sky** 0 to 62%: the gradient, four big clouds, a 12% white light-ray fan from the meteor.
2. **Far (keep it simple, three things only):** Meteor Peak at the right (66 to 100% by 22 to 60%) with glowing rim and smoke plume; one sky island top-left (8 to 28% by 8 to 26%); the cream rampart with merlons and a corner tower across the width at 58 to 66%, hazed.
3. **Ground:** cream plaza, yellow ring and the crater bowl, bottom right (30 to 100% by 64 to 100%).
4. **The Iron meteor, giant:** **42 to 96% by 18 to 86%** (it fills over half the frame). Dark rust crust, thick glowing orange cracks (`#FFB24A` to `#FFF078`), 3 bright embers, dust shockwave ring on the plaza, a strong orange glow.
5. **Hero miner** (`swing`, Plasma Pick raised): **10 to 40% by 30 to 100%**, about 70% of the frame height, cropped a little by the bottom edge. Orange armour, red plume. Beside him, small at his feet, a **Pebble Pup**; above his shoulder a flying **Meteor Drake** (28 to 40% by 18 to 34%). One friend miner (blue armour) at the far left (0 to 10% by 60 to 100%), no more.
6. **FX:** 4 gold floating hit numbers from the meteor, a spray of rock chips, 3 coins, 20 sparkles, bloom on the cracks.
7. **Text:** the wordmark lockup (section 2.3), top-left, **x 4 to 50%, y 4 to 30%**. Nothing else.

**Colour story:** orange meteor against blue sky. **Don't:** more than 4 characters, tiny landmarks, a dusk mood.

---

## 7. THUMBNAIL 2: "PICKAXE POWER" (`thumb-2-pickaxe-power.png`)

**Role:** the progression thumbnail, modelled on the reference's three-panel "+1 / 67K / 999T" weapon thumbnails and "NOOB / PRO / HACKER". Shows that gear goes from a plain pick to a cosmic one.

**Layout:** three vertical panels, each 640 px wide, split by **14 px white gutters with an ink outline**, the gutters leaning 6° from vertical. Each panel has its own background colour that gets hotter to the right, and the hero pickaxe grows and glows more in each.

| Panel | x | Background | Pickaxe (`blender/equipment`) | Big number |
|---|---|---|---|---|
| 1 | 0 to 33% | blue `#56BAFF` to `#1E68E8`, plain | `pickaxe_t1`, Basic, 55% of the panel height, tilted -20° | `x1` |
| 2 | 33 to 66% | orange `#FFD250` to `#FF801A` with soft rays | `pickaxe_t4`, Plasma Pick, 75% of the panel height, cyan glow | `x5` |
| 3 | 66 to 100% | purple `#D480FF` to `#8C32E8`, pink-white rays, sparkles, flames | `pickaxe_t8`, Cosmic Pick, 92% of the panel height, magenta bloom, orbiting sparkles | `x20` |

- **The numbers are ore per hit** (`Config.Pickaxes[tier].OrePerHit` is 1, 5 and 20 for tiers 1, 4 and 8). Re-read the config and the Gear Hall card before drawing them and use what the game shows. Cap height **210 px**, white face, ink outline, a lip in the panel's dark colour, at the top of each panel (y 4 to 24%), each with a small white pickaxe glyph at its left, like the reference's sword icon.
- **Caption ribbon,** one blue ribbon across the bottom centre (x 30 to 70%, y 88 to 96%): `ORE PER HIT` (white, cap height 56 px).
- **Small progress accents** in the lower corners of panels 2 and 3 (like the reference's `+67` and `+999T`): a green chip with an up arrow. Arrows only, no extra numbers.
- **A tiny avatar** holding each pick is optional; if used, the same miner at 25% of the panel height at the bottom-left of each panel. The pickaxe is the hero.

**Don't:** show prices or damage tables; use more than 3 panels; add scenery behind the picks.

---

## 8. THUMBNAIL 3: "HATCH A LEGENDARY" (`thumb-3-hatch-legendary.png`)

**Role:** the pet reveal, modelled on the reference's "egg, red arrow, big pet, 1 IN N" thumbnails (Sky Clickers, Pet Dice, the white cat with rays).

**Background:** full-frame sunburst, 20 alternating rays from the pet, `#FFF078` and `#FFB21E`, becoming orange `#FF801A` at the edges; add a soft white radial glow behind the pet and large bokeh circles. Sparkles everywhere in the right half.

**Layers:**
1. **Left, the egg** (`blender/eggs/egg_meteor`, the Meteor Egg), **5 to 36% by 30 to 86%**, on a small round pedestal, slightly tilted, one small crack with white light. Soft shadow.
2. **The red arrow** between them, **36 to 52% by 38 to 62%**: `#E21A38` face with a white 0.05H outline and an ink outer outline, a bevel, bent slightly, about 260 px long.
3. **Right, the Meteor Drake** (`blender/pets/meteorDrake_lv10`, the only Legendary in the Meteor Egg), **50 to 98% by 6 to 92%**: huge, 3/4 view facing left toward the egg, wings spread, a gold halo ring `#FFBE3C` behind it, lots of sparkles and a ring glow. This is the brightest object in the frame.
4. **Text,** three elements:
   - `1 IN 200` top right, **x 52 to 98%, y 3 to 24%**, cap height 190 px, white face, ink outline, gold lip; the "200" is gold. **Compute it from the config** (100 divided by `Config.Pets.Eggs` meteorEgg `Odds.legendary`, which is 0.5, gives 200) and confirm the Drake is the only non-premium Legendary; if the odds change, change the art.
   - A gold ribbon `LEGENDARY!` diagonal across the lower left of the pet, **x 48 to 80%, y 76 to 90%**, cap 72 px.
   - A **green `HATCH!` pill button** with an egg icon, bottom left, **x 4 to 30%, y 88 to 96%**, cap 54 px, ink outline and a lip, like the reference's `E HATCH!`. The game has a green HATCH button on the Pets EGGS tab, so this is honest; do **not** draw a key letter.
5. A hint of the Hatchery behind the egg (a few blurred pastel pillars) is optional; skip it if the left feels busy.

**Don't:** show an egg price in Robux, "SECRET", "NEW", "UPDATE", odds for other pets, or a slot-machine look. (Eggs are bought with Core Shards earned in play, and the pity system is not shown.)

---

## 9. THUMBNAIL 4: "REBIRTH x5" (`thumb-4-rebirth.png`)

**Role:** the economy payoff, modelled on the reference's diagonal before/after split (Heroes RNG) and the money-pad `x2 ... x100` thumbnail.

**Layout:** a **diagonal split** from the top right (x 62%) to the bottom left (x 38%), a white ink-outlined 16 px slash.
- **Upper-left triangle (before):** dull blue-grey `#8EA6C8` to `#5A729C`, no rays. A small stack of **3 iron bars** (`blender/items/bar_iron`) on a plain plinth at 6 to 30% by 52 to 86%, a tiny miner in basic gear (t1 pick) at 22 to 36% by 56 to 88%, a big white `x1` at **6 to 34% by 8 to 34%** (cap height 170 px, ink outline).
- **Lower-right triangle (after):** vivid magenta-violet `#D480FF` to `#8C32E8` with pink-gold rays. The **Rebirth Monument's glowing portal ring** (stepped round plinth, two gold-capped columns, a swirling `#FF6EBE` to `#FFFFFF` portal, the white-pink rebirth emblem from `assets/hud/rebirth.png` as a floating badge) at **54 to 92% by 20 to 74%**. A **mountain of gold bars and coins** spilling toward the camera across the bottom (40 to 100% by 66 to 100%), 12 to 18 coins in the air. The miner (orange, t4 pick) leaps in front of the portal at 40 to 56% by 40 to 90%, one fist up.
- **Text:**
  - `x5` huge at **62 to 98% by 2 to 34%**, cap height **260 px**, gold gradient face, thick ink outline, a lip `#AA4608`, a soft pink glow behind it; the `x` is smaller and white. A **green up arrow** (`#B2FF4A` to `#32C41E`, white outline) at its right, 150 px tall.
  - A pink ribbon `REBIRTH` (cap 72 px, white, ink outline, pink `#FF6EBE` face) crossing the portal base at **48 to 80% by 78 to 90%**.
- `x5` is true: `Config.Rebirth.CashMult` is 5 (the bar sales multiplier for each listed rank). Re-read it before drawing and use the game's value. Do not add cash amounts or rebirth costs.

**Don't:** show the HUD, real cash totals, or more than 2 numbers (`x1` and `x5`).

---

## 10. THUMBNAIL 5: "BOSS METEOR" (`thumb-5-boss-meteor.png`)

**Role:** the co-op high point, a more dramatic version of T1: the Alien boss meteor everyone cracks together. It brings in the green and lime colours the other four don't have.

**Camera:** closer, slightly high three-quarter looking into the crater, 45 mm.

**Layers:**
1. **Background:** radial burst `#B0FF5C` at the centre to `#32C41E` to deep teal `#0E5A60` at the edges, 16 rays, a few big floating bokeh circles; at the top, a faint Meteor Peak silhouette and cloud puffs.
2. **The Alien boss meteor** (crust `#3EB07E` / `#56CC94` / `#30966E`, glow `#6EFFA0`, core `#46EB78`), the **broken variant** (about 60% of the crust is gone, a huge exposed glowing core with neon veins), **26 to 78% by 20 to 88%**, strong mint bloom, an energy column to the top edge.
3. **Four miners** around it in `swing` poses (orange, blue, violet, pink armour; picks t4, t5, t6, t8), the two big ones in the foreground at **4 to 28% by 42 to 100%** and **72 to 96% by 46 to 100%**, the other two smaller at the back left and right. They look at the core.
4. **FX:** 10 blue **Core Shards** (`blender/items/core_shard`) arcing out of the core, rock chips, gold `CRIT!` numbers, a cyan flash ring behind the core, sparkles.
5. **Text:** `BOSS METEOR!` in one line at the top centre, **x 14 to 86%, y 3 to 24%**, cap height 190 px, lime-white gradient face (`#FFFFFF` to `#B0FF5C`), ink outline, a lip `#166E12`, tilt -3°. Below it a small gold ribbon `CRACK IT TOGETHER` (cap 52 px) only if the middle top feels empty. No numbers.

**Don't:** show a HP bar or damage maths, fighting between players, or text over the core.

---

## 11. THE LOADING SCREEN

### 11.1 Goals
- Shows instantly (before the game finishes loading), never blocks play for more than about 25 s, and fades out only once the game is ready (assets in, player state received, HUD built).
- It is the same cartoon family as the HUD: sky, the crater, the falling meteor and a chunky progress bar. Rotating, true gameplay tips so new players learn the loop.
- Works at phone size and respects `ReduceEffects` (`player:GetAttribute("ReduceEffects") == true`, as used by `HatchController` and `HUDController`).
- Currently there is **no loading screen**: Roblox's default shows. `src` has no `ReplicatedFirst` content and `default.project.json` has no `ReplicatedFirst` mapping.

### 11.2 Layout (reference frame 1920×1080; it scales with `ScaleType = Crop` for the art and scale-based sizes for the rest)
- **Layer 0, SkyGradient:** a full-screen Frame, `UIGradient` rotation 90, `#3E9BFF` to `#BFEBFF`. Shown instantly as the fallback while the art loads.
- **Layer 1, Backdrop (`loading-bg.png`, 2048×1152):** low wide view of the Crater Isle seen from across the lagoon: the rampart, the Foundry chimney, Meteor Peak with its plume at the right, two sky islands, a lighthouse, and a **dark empty crater at the centre-left (x 38%, y 62%)** that the animated meteor falls into. **No text and nothing important in the bottom 38%** (the UI sits there). Render it with the same Blender pipeline (section 3) using the isle diorama, camera low and wide, 24 mm.
- **Layer 2, Clouds:** two or three `cloud.png` sprites (512×256, transparent) drifting slowly left to right (60 to 90 s per crossing), at 8 to 25% height. Skipped with `ReduceEffects`.
- **Layer 3, Falling meteor loop:** the meteor sprite (`Config.HudIcons.meteor`, 256 px) enters from the top right (x 90%, y -10%) and falls diagonally to the crater (x 38%, y 62%) in **2.2 s** (`Quad` In), with a `trail.png` streak (a gold-orange gradient, rotated to the path) behind it that fades. On arrival: a white-orange flash ring (a circle Frame with a `UIStroke`) expanding from 0 to 22% of screen width while fading in 0.5 s, 6 chips (small orange Frames) bursting up, and a 0.25 s, 6 px shake of the logo group. Then a 1.4 s pause and loop. With `ReduceEffects` it shows the meteor sitting in the crater, glowing, with no loop.
- **Layer 4, Logo group:** `wordmark.png` (the full lockup, transparent) centred at **x 50%, y 24%**, width 52% of the screen width (cap at 1100 px and a minimum 360 px via a `UISizeConstraint`), a gentle bob of ±6 px over 2.4 s (`Sine`), and one shine sweep (a diagonal white gradient with 35% alpha) every 5 s.
- **Layer 5, Progress panel,** bottom: a panel centred at **x 50%, y 86%**, width `min(720 px, 84%)`, height 150 px. A `Cartoon.surface("deep")`-style body: ink outline 3 px, a lip, rounded 16 px. It contains:
  - A status line at the top left, `Fredoka One` 24 px, white with an ink stroke, e.g. `Waking up the crater...` and the percent at the top right in gold (`#FFF078`), e.g. `63%`.
  - The **progress bar:** a pill 34 px high, the track `#1648BE` with an ink outline, the fill a green gradient `#B2FF4A` to `#32C41E` with two diagonal gloss stripes sliding (an `UIGradient` offset animated), a soft top shine, and a small **pickaxe icon** (`Config.HudIcons.equipment` or a white pickaxe sprite) at the fill head that swings ±20° every 0.5 s.
  - **The tip row:** a gold chip `TIP` (Cartoon "gold" colours) then the tip text, Fredoka One 22 px, white with an ink stroke, one line (truncate with an ellipsis), cross-fading every 4.5 s.
- **Phone:** below 700 px of height the panel is 92% wide and 130 px high, the logo is 70% wide and centred at y 20%, the tip text drops to 18 px. The art uses `Crop`, so keep the crater near the centre-left of the image, never at its edges.
- **Dismissal:** a 0.15 s white flash then the whole group fades over 0.5 s (`GroupTransparency` on a `CanvasGroup`, or tween each layer), then destroy the ScreenGui.

### 11.3 Tips (true to the game; keep each under 60 characters; write them in `Config/Loading.luau`)
1. `Mine the glowing rocks between meteors.`
2. `A meteor lands every few minutes. Run to the crater!`
3. `Hit the core together to earn Core Shards.`
4. `Deposit ore at the Foundry, then claim your bars.`
5. `Sell bars at the Trading Post for cash.`
6. `Hold SPRINT to run faster.`
7. `Tap ORE to teleport to an ore field.`
8. `Hatch eggs with Core Shards you earn by playing.`
9. `Pets level up while you mine.`
10. `Evolve your pickaxe at the Gear Hall.`
11. `Rebirth to multiply your cash and unlock more pet slots.`
12. `Ice meteors refreeze, so keep hitting them!`
13. `Crystal meteors get stronger when friends join in.`
14. `Bigger backpacks mean longer mining trips.`

Status lines by progress: 0 to 15 `Waking up the crater...`; 15 to 55 `Polishing the pickaxes...`; 55 to 85 `Counting your ore...`; 85 to 99 `Firing up the foundry...`; 100 `Ready!`.

### 11.4 Code architecture (match the repo: `--!strict`, tabs, Luau, no new libraries)
1. **`default.project.json`:** add
   ```json
   "ReplicatedFirst": {
     "$className": "ReplicatedFirst",
     "$ignoreUnknownInstances": true,
     "LoadingScreen": { "$path": "src/loading" }
   }
   ```
   (a `LocalScript`, `LoadingScreen.client.luau`). Rojo is usually not connected in Studio here: sync it by creating `ReplicatedFirst.LoadingScreen` (a `LocalScript`) in Studio and setting its `.Source` from `HttpService:GetAsync("http://127.0.0.1:8124/src/loading/LoadingScreen.client.luau", true)` after a `loadstring` compile check (the repo server is `python -m http.server 8124 --bind 127.0.0.1` at the repo root).
2. **`src/shared/LoadingProgress.luau` (pure logic, unit-tested):**
   - `LoadingProgress.new(weights: { [string]: number })` with stages `engine` 0.15, `assets` 0.45, `state` 0.25, `hud` 0.15 (sum 1).
   - `:setStage(name, fraction)` clamps 0 to 1; `:total()` returns the weighted sum, **never decreasing** (keep a high-water mark).
   - `LoadingProgress.ease(display, target, dt)` returns the next displayed value: exponential approach `display + (target - display) * (1 - math.exp(-dt * 6))`, never above `target`, snapping within 0.001, so the bar never jumps.
   - `LoadingProgress.status(percent)` returns the line from 11.3.
   - `LoadingProgress.nextTip(count, previous)` returns a tip index, never the same as `previous` twice in a row, deterministic from a seed.
   - `LoadingProgress.shouldFinish(elapsed, total, minShow, maxShow)` is true when `total >= 1 and elapsed >= minShow`, or `elapsed >= maxShow`.
3. **`src/shared/Config/Loading.luau`:** the tips, the status thresholds, `MinShow = 2.5`, `MaxShow = 25`, `TipSeconds = 4.5`, the asset ids (`Background`, `Wordmark`, `Cloud`, `Trail`, filled in after the owner uploads: leave them as empty strings with a fallback path so the script works before the art exists), and the Preload list.
4. **`src/loading/LoadingScreen.client.luau`:**
   1. First line: `ReplicatedFirst:RemoveDefaultLoadingScreen()`.
   2. Build the ScreenGui straight away, **without waiting for anything**: `ResetOnSpawn = false`, `IgnoreGuiInset = true`, `DisplayOrder = 1000`, `ZIndexBehavior = Sibling`, parented to `PlayerGui` (`player:WaitForChild("PlayerGui")`). The gradient, panel, bar and status text are plain Instances in this script so they exist before `ReplicatedStorage` replicates. The art is set when its image loads.
   3. `ReplicatedStorage:WaitForChild("Shared")` (a few frames), then require `LoadingProgress` and `Config.Loading`. Until then the bar eases from 0 to 12% on a timer so it never looks frozen.
   4. **Stage `engine`:** `game:IsLoaded()` or `game.Loaded:Wait()`.
   5. **Stage `assets`:** `ContentProvider:PreloadAsync(list, callback)`, with the callback incrementing a counter (`count / #list`). Preload list: the loading art first, then every `rbxassetid://` in `Config.HudIcons`, then `ReplicatedStorage.PetModels` and `MeshArt` descendants that are MeshParts (at most 300 instances; skip the rest). Wrap it in `task.spawn`, `pcall` it, and treat a timeout of 12 s as done (stage = 1).
   6. **Stage `state`:** wait until the player's state has replicated. Find the cheapest existing signal first (`PlayerStateService.State` is what `HUDController` observes through Knit: `PlayerStateService.State:Observe(...)` at `src/client/Controllers/HUDController.luau:139`; if a simple, signal-free marker is better, have `HUDController` set `player:SetAttribute("HudReady", true)` after its first state and wait on that attribute). The loading screen must not depend on Knit directly, because Knit starts later: use the attribute, and add the one-line `SetAttribute` in `HUDController`.
   7. **Stage `hud`:** the same `HudReady` attribute (set after the HUD has built and received its first state), then one `RunService.RenderStepped:Wait()`. Stages `state` and `hud` can share the one signal, so weight them together if no separate signal is cheap to add.
   8. Update loop on `RunService.RenderStepped`: eased bar fill and percent, the pickaxe at the fill head, the tip rotation timer, the meteor loop, the clouds, the status line.
   9. Finish by `shouldFinish`, then do the flash and the fade, then `player:SetAttribute("LoadingDone", true)` and destroy the ScreenGui. A dev hook: if `ReplicatedFirst:GetAttribute("HoldLoading") == true` never finish (for screenshots), and log with `warn` only on timeout.
   10. Tutorial and landing-camera behaviour are unaffected (they run behind the screen); but if the first countdown ends while the screen is up, that is acceptable.
5. **`tests/LoadingProgress.spec.luau`** (use `t.test`, `t.eq`, `t.near`, `t.ok`; require from `t.shared`): weights sum to 1; `total()` is monotonic even if a stage is set lower; clamping outside 0 to 1; `ease` converges, never overshoots and never goes backwards; the status thresholds at 0, 14.9, 15, 54.9, 55, 84.9, 85, 99.9, 100; `nextTip` never repeats twice in a row for 200 draws and visits every index; `shouldFinish` truth table (done early waits for `minShow`, a stalled load ends at `maxShow`). The suite must stay green (currently **489 passed, 0 failed**; run `require(game.ServerStorage.Tests.Runner)()` in Edit mode).
6. **Docs:** a short "Loading screen" section in `README.md` or `docs/` listing the files, the tips config and the asset ids.

### 11.5 Art to produce for it
- `loading/loading-bg.png` 2048×1152 (the section 11.2 backdrop, no text, UI-safe bottom 38%, crater at x 38% y 62%).
- `loading/wordmark.png` the transparent lockup, 2048 px wide (same file as section 2.3).
- `loading/cloud.png` 512×256 transparent, white with the lavender underside and ink outline at half weight.
- `loading/trail.png` 512×128 transparent, a horizontal gold-orange streak (white-hot core, orange edge, alpha fade to the left), designed to be rotated.
- The meteor sprite already exists (`Config.HudIcons.meteor`, `rbxassetid://119161441061514`); the pickaxe sprite can reuse `HudIcons.equipment`.

**Uploading:** the owner uploads, or the agent uploads with the Studio MCP image upload tool only after the owner agrees. An `ImageLabel` needs the **Image** asset id, not the Decal id (they differ). Verify each id by putting it in a test `ImageLabel` and looking at it, then write the ids into `Config/Loading.luau`.

### 11.6 Verification
- Unit tests pass.
- In Edit mode, build the ScreenGui once (the script run with `HoldLoading = true`) and take `screen_capture` at desktop size and at a phone-sized viewport (Device emulator or resize the screen gui parent), checking: the logo, the bar, the tip and the percent are legible and not clipped; nothing overlaps the Roblox top bar area; the panel never exceeds 84% width.
- **Studio Play mode:** the owner has said never to use Play mode because it crashed their PC; they allowed it only for earlier tasks. **Ask them before starting Play for this one.** If allowed, check the full flow once: loading shows, the bar completes, the screen fades, the HUD and tutorial card appear, and the console has no errors from `LoadingScreen`.
- Slow-path test: temporarily set `Config.Loading.MaxShow = 4` to see the timeout path, then restore.
- The screen must never leave the game stuck: pcall everything in the update loop, and on any error destroy the ScreenGui and warn.

---

## 12. Order of work and acceptance

**Order:**
1. Style bible and wordmark (2.3). Review the wordmark at small size.
2. Blender tooling (`common.py`, `miner.py`, `isle.py`, `foundry.py`): render a **test frame of each** (miner pose, the isle from the T1 camera, the meteor, the foundry) and view them. Fix the look before building shots.
3. The icon (the smallest, the fastest way to validate the look).
4. T3 (the pet reveal, the quickest win), T2 (pure 3D props on flat panels), T1, T5 (both need the meteor and the miner), T4 (needs the portal and the gold pile).
5. The loading screen art (reuse the isle render), then the code, the tests and Studio verification.
6. Contact sheet and small-size sheet; write a README in `tools/key-art` and a one-page `assets/marketing/v2/README.md` (the files, sizes, how they were made, and what the owner uploads where).

**Acceptance checklist (tick each in the final report):**
- [ ] All eight image files are the exact sizes in section 0 (check with Pillow) and under 5 MB each.
- [ ] Every thumbnail passes the small-size test (3.4) and the 5-up grid check: hero readable at 256×144, text legible at 384×216, safe margins held, each thumbnail reads in about one second.
- [ ] Every number or odds figure on a thumbnail (`x1 x5 x20`, `1 IN 200`, `x5`) is traced to a config value, with the file and value written in `assets/marketing/v2/README.md`.
- [ ] The icon reads at 150 px and 64 px; no text; no baked corners.
- [ ] Same wordmark, same ink colour `#0E1834`, same Fredoka One family across all pieces; the costume of the miner is identical everywhere.
- [ ] Colours match the palette in 2.1 and the meteor, pet and field colours in section 1 (spot-check with a colour picker: sample 3 points per piece).
- [ ] No Roblox logo, Robux symbol, "FREE", "SECRET", "NEW", sale copy, invented stats or real people. (Only the true, config-derived figures above.)
- [ ] Loading screen: tests pass (the whole suite stays green), it shows in under a second of the script running, never exceeds `MaxShow`, scales on a phone viewport, honours `ReduceEffects`, and cleans up its ScreenGui.
- [ ] Nothing committed, pushed, uploaded or published; Studio Play not used without asking; the report says exactly what the owner must do (upload the icon and thumbnails in Creator Hub, upload the loading art and give back the ids, save the place from Studio).

**Do not:** reuse the old dusk/teal vector art, change gameplay or balance, edit the map or HUD apart from the one `SetAttribute` line in `HUDController`, add dependencies, or leave large intermediate renders in the repo root.
