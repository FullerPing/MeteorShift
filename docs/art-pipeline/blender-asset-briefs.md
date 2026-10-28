# Blender asset briefs (Craterworks: Meteor Mining)

Every 3D model the game would use as a mesh instead of today's Roblox part builds. Hand this file to the modelling agent. Each entry gives the file name, the size in studs, what it looks like, which pieces must be separate objects, and the colours. Read the global rules first; they apply to every entry.

Nothing in the game uses a Blender mesh yet. Equipment, pets, eggs, meteors, rocks and the map are built from Roblox parts by code. Each section ends with **Hook**, which says where the mesh plugs in once it exists.

---

## 0. Global rules

### Style
- Cartoon simulator, in the style of Pet Simulator X and Mining Simulator 2. The shapes are chunky, rounded and readable from far away, with bevelled edges (2 to 3 segment bevels on every hard edge), slightly exaggerated proportions and no realistic detail noise.
- Use flat colours in **three tones per material**: light on the top faces and highlights, body on the main faces, dark on the bases and undersides. No PBR, no normal maps, no noise textures.
- Glowing parts (energy, lava, crystal cores) are plain bright colours. Roblox makes them glow with the Neon material, so model them as **separate objects** (see "Separate objects").
- A thin darker trim band at the big edges is welcome, because it reads as a cartoon outline.

### Scale and orientation
- Model with **1 Blender unit = 1 Roblox stud**. The sizes below are in studs. The importer can rescale, but the proportions must match.
- **Front faces Blender −Y.** This becomes Roblox −Z after import ("front" means the side a player looks at). Up is +Z.
- **Origin (pivot) at the bottom centre** of the model, unless the entry says otherwise. Equipment and pets have their own pivot rules.
- Apply all transforms before export (Ctrl+A → All Transforms).

### Geometry budgets (triangles per whole asset, all objects together)
| Kind | Budget |
|---|---|
| Small prop (crate, lamp, flower) | ≤ 800 |
| Pickaxe or backpack | ≤ 3,000 |
| Pet (each of the two looks) | ≤ 5,000 |
| Egg | ≤ 2,000 |
| Debris rock | ≤ 1,500 |
| Meteor crust node piece | ≤ 3,000 |
| Meteor core | ≤ 10,000 |
| Map hero piece | ≤ 8,000 |

Roblox caps a single mesh at 20,000 triangles. No asset should need that.

### Materials and textures
- **Palette texture:** one shared 256 × 256 PNG, `palette.png`, with flat swatches of the colours in the "Shared palette" section. Collapse each face's UVs onto the swatch it should use. Every model can then share one texture. Do not bake lighting into it.
- **Tinted parts have no texture.** Some parts are recoloured by the game at runtime: a pet's `Body`, rock flecks, meteor crust and ore, and any part marked *tint*. Make those a separate object in plain white or light grey with no UVs needed; Roblox sets their colour.
- **Neon parts have no texture** and are separate objects, coloured in Roblox.

### Separate objects
A single object becomes one Roblox MeshPart. Split a model into separate objects only where the game needs it:
1. a part that is **tinted** at runtime;
2. a part that **glows** (Neon);
3. a part that **moves** (a pet's legs, wings, tail, head, drill, rotor or halo; a backpack's spinning core);
4. a part that **swaps or hides** (pet working props, the level-10 extras).

Otherwise **merge**: fewer objects means fewer parts in the game. Name every object exactly as given (for example `Body`, `FrontLeg`, `Vein`).

### Export
- FBX per asset: Selected Objects, Apply Transform, Mesh + Empty only, no animation, triangulate on export.
- Also save the `.blend`.
- Folder layout:
  ```
  blender/
    palette.png
    equipment/pickaxe_t1.fbx … pickaxe_t8.fbx, backpack_t1.fbx … backpack_t8.fbx
    pets/<petId>.fbx, <petId>_lv10.fbx
    eggs/egg_meteor.fbx, egg_crystal.fbx, egg_aurora.fbx
    meteor/meteor_core.fbx, node_piece_a.fbx … node_piece_d.fbx, ore_chunk.fbx, minerals/<mineralId>.fbx
    items/bar_<ore>.fbx, ore_<ore>.fbx, coin.fbx, core_shard.fbx
    rocks/rock_<biome>_a.fbx … _c.fbx
    map/<Name>.fbx
    props/<name>.fbx
  ```
- For each asset, render a 512 × 512 PNG preview (front three-quarter view, transparent background) next to the FBX. These double as shop and index icons (see section 10).

---

## Shared palette (hex)

Three-tone ramps, listed light / body / dark:

| Ramp | Light | Body | Dark |
|---|---|---|---|
| orange | #FFB24A | #FA8028 | #BA4E1A |
| red | #FF7068 | #E8403A | #A02228 |
| blue | #6CB8FF | #2E80F0 | #1C4AA8 |
| navy | #465882 | #283456 | #161E36 |
| pink | #FFB0E2 | #FA78C8 | #C44696 |
| violet | #CE9CFF | #A462F6 | #6C38BA |
| gold | #FFE66E | #FFC428 | #CE8C14 |
| green | #8CE262 | #58C440 | #308C34 |
| teal | #78ECDE | #2CC8BE | #148A8C |
| frost | #DCF8FF | #96DEFF | #54A8DE |
| stone | #C8CEDC | #96A0B4 | #626C84 |
| wood | #D6985C | #A86C3E | #70462A |
| cream | #FFFAE8 | #FFECC4 | #DEC496 |
| sulfur | #FAF078 | #DEC83C | #968022 |
| rust | #D67C54 | #AA5638 | #703626 |

Single colours:
- white #FCFCFF
- ink #1C2034 (outlines, sign boards, details)
- glass #A8E2FF
- warm glow #FFD678
- equipment dark #1D2533
- steel #859CB1
- light steel #E3F1F9
- equipment gold #FFC95C
- cyan #6DEFFF

Rarity colours:
- Common #B0BAC6
- Uncommon #78DC8C
- Rare #5AAAFF
- Epic #BE78FF
- Legendary #FFBE3C
- Premium #FF6EBE

---

## 1. Pickaxes (8): `equipment/pickaxe_t1` … `pickaxe_t8`

One pickaxe evolves through eight tiers. The player holds it, the Gear Hall shows it on tier walls and stands, and the shop shows it in a 3D preview.

**Common to all tiers**
- About **4.6 studs tall** (shaft about 4.2) with a head about **3.5 to 4 studs wide**.
- The shaft runs along +Z (up) and the head runs along the X axis, centred at the top.
- **Pivot at the grip:** 1.4 studs above the bottom of the shaft, centred.
- Separate objects:
  - `Shaft`: handle, grip bands and pommel merged.
  - `Head`: the main head.
  - `Accent`: *tint*, the tier colour.
  - `Glow`: *neon*, where listed.
- Tier accent colour (applied to `Accent`): T1 #96969B, T2 #BECDDC, T3 #FFB030, T4 #50DCFF, T5 #FF6028, T6 #BA6CFF, T7 #281E3C, T8 #FF78DC.

| Tier | Name | Look |
|---|---|---|
| 1 | Basic Pickaxe | A wooden handle (wood ramp) with dark grip wraps. A plain forged grey head: a curved pick point on one side and a short square hammer end on the other. Slightly chunky and friendly. |
| 2 | Steel Pickaxe | A dark metal handle and a dark steel socket. Two symmetrical swept steel wings with bright light-steel cutting edges. A small gold diamond badge on the socket. Sharper and cleaner than T1. |
| 3 | Drill Pick | The head is a hand drill. A dark motor cylinder with an orange accent casing and three vent slits leads into a five-step tapered drill bit (alternating steel and light-steel bands, twisted) ending in a sharp tip. A diagonal orange brace runs from the shaft to the motor. |
| 4 | Plasma Pick | A dark reactor box at the head with a round cyan plasma core on the front (*neon*). Two forked steel arms angle up and out to glowing cyan energy prongs (*neon*), with thin glowing rails along the arms (*neon*). |
| 5 | Meteorite Pick | A rough charcoal meteorite lump with four jagged obsidian shards fanning out along the head. Two glowing orange-red molten fissures run across the front (*neon*), and a hot glowing core shows through a crack (*neon*). |
| 6 | Nova Pick | A star burst. Six gold spokes radiate from a glowing violet central star (*neon*), each tipped with a violet crystal (*neon*), and a thin silver ring crown circles the centre. |
| 7 | Singularity Pick | A steel containment ring holding a glossy near-black sphere (*tint* #281E3C). A thinner violet glowing event-horizon ring sits inside it (*neon* #9661FF). Two curved steel gravity blades sit either side, with cyan field emitters (*neon*) where the blades meet the ring. |
| 8 | Cosmic Pick | A crescent moon blade in light steel with a pink glowing inner edge (*neon*), plus a long comet blade sweeping back (*neon* pink). A tilted gold halo ring orbits the centre. A white four-point star (*neon*) sits over a pink glowing heart orb (*neon*). The most ornate tier. |

**Hook:** `src/shared/EquipmentModels.luau` `pickaxe(tier)` builds these from parts today. It would clone `ReplicatedStorage.EquipmentMeshes.Pickaxe<tier>` and keep the same axes and pivot.

---

## 2. Backpacks (8): `equipment/backpack_t1` … `backpack_t8`

These are worn on the character's back and shown on Gear Hall walls.

**Common to all tiers**
- About **2.0 × 2.6 × 1.2 studs** (width × height × depth). T6 to T8 can be up to 2.8 wide and 3.3 tall.
- The straps side (the side against the back) faces +Y in Blender. The outward face is −Y.
- **Pivot** at the centre of the strap face.
- Two dark shoulder straps on the back face, part of `Body`.
- Separate objects:
  - `Body`
  - `Accent`: *tint*, the same tier colours as the pickaxes.
  - `Glow`: *neon*, where listed.
  - `Core`: moving, where listed.

| Tier | Name | Look |
|---|---|---|
| 1 | Canvas Sack | A soft, slightly lumpy tan canvas sack (#A0865D) with a folded lighter flap (#C2A978), a dark tie down the front and a small front pocket. Stitched seams. |
| 2 | Leather Pack | A rounded brown leather pack (#754229) with a lighter flap (#9F6337), two dark belts down the front and two brass buckles (gold). |
| 3 | Miner's Pack | A grey-green canvas pack (#4B5A5B). Its parts: <ul><li>an orange front pouch (`Accent`);</li><li>a round work lamp on a dark plate (*neon*, warm gold);</li><li>a rolled tan bedroll strapped across the top;</li><li>a dark side pocket.</li></ul> |
| 4 | Reinforced Pack | A dark armoured case with a steel front plate, light-steel corner rails, three horizontal ribs and a cyan status light bar (*neon*). |
| 5 | Ore Hauler | A brown-metal ore bin (#624431) with gold exo-rails up both sides, dark side bins and three steel bands. Rough orange ore chunks (`Accent`) poke out of the open top. |
| 6 | Cargo Rig | A dark frame holding four steel cargo modules in a 2 × 2 grid, each with a violet glowing latch (*neon*). Gold rig legs run down the sides, and there is a central spine. |
| 7 | Gravity Pack | A dark housing. On the front, a steel halo ring with a violet glowing field ring inside it (*neon*) around a glossy dark gravity orb (`Core`, slow spin). Two steel cylinder cells sit on the sides, with cyan glowing undersides (*neon*). |
| 8 | Void Pack | A dark housing with a big purple void diamond on the front (#4C2C6B). Its parts: <ul><li>an orbit ring of pink light (*neon*);</li><li>a cyan glowing heart (*neon*);</li><li>two light-steel wing blades flaring out sideways, with pink energy lines (*neon*);</li><li>a small gold crown gem on top.</li></ul> |

**Hook:** `EquipmentModels.backpack(tier)` and `applyToCharacter`.

---

## 3. Pets (14 pets × 2 looks): `pets/<id>.fbx` and `pets/<id>_lv10.fbx`

The full art direction is in `docs/guide/pets.md`; follow it. The rules below are the mesh-specific ones.

**Size**
- Ground pets are about 2.5 to 3.5 studs tall.
- Flyers are about 2 to 3 studs.
- The Meteor Drake is dog-sized, about 4 studs.

**Pivot and facing**
- Pivot at the centre bottom (ground pets) or the body centre (flyers).
- The face looks −Y.

**Objects**
- **`Body`** (required): the main torso. It is *tinted* with the pet colour, so model it white or light grey with no texture.
- **Animated pieces:** each is a separate object, named after its animation group. The game animates these names:
  - `Head`, `Ears`, `Tail`
  - `FrontLeg` (both front legs may be one object, or split into `FrontLeg` and `FrontLeg.001`)
  - `BackLeg`
  - `WingsLeft`, `WingsRight`
  - `Drill`, `Halo`
  - `OreChunk`: a small ore lump that hops out when the pet hauls.
- **Hidden work props** stay invisible until the pet does its job. Model them in their rest place as separate objects with these names:
  - `GreyChip`: stone chips (Pebble Pup)
  - `SparkLink`: a spark bolt (Spark Hare)
  - `CoinGlint`: a coin flash (Magpie)
  - `TargetShard`: crystal shards (Stag)
  - `TunnelLight` and `TunnelOre`: a light tunnel and ore (Wyrm)
  - `FlameBreath`: a flame cone (Drake)
  - `ArrivalStreak`: a meteor streak (Drake)
  - `HeatWave`: a shimmer (Drillbot)
  - `WorkingRing`, `ScorchGlow`: a sunlight ring and ground glow (Phoenix)
- **Glow parts** (eyes, cracks, crystals, flames) are separate *neon* objects.
- **Level 10 look:** a second complete file, `<id>_lv10.fbx`. It uses the same names, plus accent trim, extra glow and slightly larger parts.
- **Pack Mule only:** its panniers are separate objects named `Pannier`. The game grows them by 15% at level 5.

| Id | Name | Rarity | Body tint | Moving parts | Look summary |
|---|---|---|---|---|---|
| pebblePup | Pebble Pup | Common | #969696 | Head, Tail, FrontLeg, BackLeg, GreyChip | A pup made of rounded pebbles. Boulder body, pebble head, stubby legs, a tail of three stacked stones and dark pebble eyes. Matte. |
| scrapSparrow | Scrap Sparrow | Common | #BEA06E | Head, Tail, WingsLeft/Right | A sparrow made of riveted tan scrap plates. One bolt eye, one mismatched eye, a copper beak and three spring tail flaps. |
| packMule | Pack Mule | Uncommon | #BEA078 | Head, Ears, Tail, FrontLeg, BackLeg, Pannier ×2 | A compact robot mule. Sandy tan, grey head, one floppy ear, a bristle mane and two buckled side panniers. |
| sparkHare | Spark Hare | Uncommon | #FFDC5A | Ears, FrontLeg, BackLeg, SparkLink | A long-eared yellow hare with a cream belly and big dark eyes. Blue-white spark crystals sit on the ear tips and paws (*neon*). |
| jetWisp | Jet Wisp | Rare | #6EDCFF | Tail (twin flames), Head | A glowing cyan teardrop spirit with a white inner core (*neon*), two soft eyes and twin wispy flame tails (*neon*). Flyer. |
| coinMagpie | Coin Magpie | Rare | #FFDC64 | Head, Tail, WingsLeft/Right, CoinGlint | A black and white magpie with a green-gold wing sheen and a long tail, holding a gold coin in its beak. The `Body` is the white chest; the black plumage is a separate object. |
| cargoMole | Cargo Mole | Rare | #967860 | Head, FrontLeg, BackLeg, OreChunk | A chubby dark-brown mole with a pink nose and claws and sleepy eyes. A yellow hard hat with a small lamp (*neon*) and a canvas satchel. |
| graniteGolem | Granite Golem | Rare | #78828C | Head, FrontLeg (arms and fists), BackLeg | A blocky charcoal granite golem. Amber eye slits (*neon*), big fists, a moss patch on one shoulder and a chest hatch that glows (*neon*, separate object `ChestGlow`). |
| crystalStag | Crystal Stag | Epic | #BE82FF | Head (with antlers), FrontLeg, BackLeg, TargetShard | A slender deer of violet crystal. Translucent-looking legs, a pearl underbelly and branching glowing amethyst antlers (*neon*). |
| lodeWyrm | Lode Wyrm | Epic | #FFAA46 | Head, Tail (segments), TunnelLight, TunnelOre | A long coiled worm in copper plates with glowing amber seams (*neon*). A blunt armoured head ringed with drill teeth, and bright eyes. Six to eight segments; each segment is a separate object named `Tail`. |
| auroraOwl | Aurora Owl | Epic | #78FFD2 | Head, WingsLeft/Right | A big owl with teal and mint feathers, wide gold eyes and ribbon-like light trails from the wing tips (*neon*). Flyer. |
| meteorDrake | Meteor Drake | Legendary | #FF8232 | Head, Tail, WingsLeft/Right, FrontLeg, BackLeg, FlameBreath, ArrivalStreak | A small dragon with charcoal scales and glowing orange lava cracks (*neon*), ember-tipped horns, a heavy tail, tiny wings and white-hot eyes. |
| drillbot | Drillbot | Premium | #FFB030 | Drill (spins), WingsLeft/Right (rotor fins), HeatWave | A polished steel drone with an orange hazard stripe (`Body`), an amber eye lens (*neon*), a spinning drill nose and two rotor fins. Flyer. Level 10 adds gold trim, bigger rotors and a blue engine glow. |
| solarPhoenix | Solar Phoenix | Premium | #FF783C | Head, Tail, WingsLeft/Right, Halo, WorkingRing, ScorchGlow | A phoenix of molten gold and white fire. Layered flame tail feathers (*neon*), a crown of rays, and a slowly rotating halo ring (`Halo`). It is the only pet with a halo. Flyer. |

**Hook:**
- `tools/build-pet-models.luau` builds `ReplicatedStorage.PetModels.<id>` today.
- The meshes would replace the parts inside each model. Keep `PrimaryPart = Body`, the `PetColor` attribute and a `Level10` folder with the second look.
- Set the `AnimationGroup` and `AnimationPivot` attributes on each moving piece. The pivot is the joint position: shoulder, hip, wing root or tail root.

---

## 4. Eggs (3): `eggs/egg_meteor`, `egg_crystal`, `egg_aurora`

These sit on the Hatchery pedestals and are used for the hatch animation.

- **Size and pivot:** about 3 studs tall and 2.4 wide (classic egg shape, slightly wider at the bottom), with the pivot at the bottom.
- **Separate objects:**
  - `Shell`
  - `Pattern`: spots and bands.
  - `Glow`: *neon*, cracks that light up during the hatch wobble.
  - `ShellTop` and `ShellBottom`: an optional split along a zig-zag crack line, for a future "crack open" effect.

| Id | Name | Look |
|---|---|---|
| meteorEgg | Meteor Egg | An orange-brown speckled egg (orange ramp), like a small meteor. Charred dark spots and a faint orange glow in the cracks. |
| crystalEgg | Crystal Egg | A blue egg (blue ramp) with faceted crystal spikes poking out of the shell (frost ramp) and cyan glowing crack lines. |
| auroraEgg | Aurora Egg | A green-teal egg (green and teal ramps) with swirling aurora bands (teal to pink) and a small gold crown of spikes on top. It shows that this is the late-game egg. |

**Hook:** the Hatchery stage (`tools/map-v2/Hatchery.luau`) builds the pedestal eggs from parts, and the hatch preview is in `HatchController`.

---

## 5. Meteor (the centrepiece event)

The meteor lands in the crater every few minutes. It is a core covered by **36 crust nodes** that players mine. The same geometry is recoloured per type (Iron, Ice, Crystal, Alien boss, and a golden variant).

### 5a. `meteor/meteor_core.fbx`
- **Size:** about **56.7 studs** in every direction. It is a rough sphere: a lumpy boulder, not a perfect ball.
- **Pivot:** at the centre.
- **Separate objects:**
  - `Core`: dark rock, *tinted* at runtime, so model it plain light grey.
  - `Vein`: a network of glowing cracks across the surface, *neon* and *tinted* with the glow colour. Make it 10 to 16 crack strips as one object, or a few objects all named `Vein`.
- **Node slots:** add 36 **empties** named `NodeSlot` spread evenly over the upper two-thirds of the surface. Their positions sit within a horizontal radius of about 33 and between Y −22 and +32 from the centre, each pointing outward along the surface normal. The game attaches crust nodes to these empties.

### 5b. Crust node pieces: `meteor/node_piece_a` … `node_piece_d` (4 variants)
- **Size:** about **40 × 17 × 40 studs**: a flattish rocky cluster that sits on the core surface. The pivot is at the bottom centre; the bottom is the face that touches the core.
- **Separate objects:**
  - `Rock`: the crust chunk, *tinted* with the crust colours, so model it plain.
  - `Ore`: 4 to 7 ore lumps studding the top, *tinted* with the ore colour.
- **Variants:**
  - a: round and lumpy.
  - b: tall with jagged plates.
  - c: wide and flat with ledges.
  - d: a spiky crystal cluster (this one reads best on the Crystal meteor).

### 5c. Ore chunk: `meteor/ore_chunk.fbx`
- About 1 stud: a faceted, gem-like nugget. It is *tinted*.
- Used for chunks that fly into the backpack when you mine, and for pet hauling.

**Colours the game applies** (for the previews only):

| Type | Crust | Ore | Core | Glow |
|---|---|---|---|---|
| Iron | #B87654 / #CC8A62 / #9C6248 | #C4AA96 (metal) | #D74E18 | #FF963C |
| Ice | #96D6FF / #7AC2F6 / #C0E8FF | #60E2FF (ice) | #28A0EB | #78ECFF |
| Crystal | #9E6CCC / #B67EDC / #845AB4 | #FF7AD6 (glass) | #CD32BE | #FF56E8 |
| Alien boss | #3EB07E / #56CC94 / #30966E | #78FF96 (neon) | #46EB78 | #6EFFA0 |

The golden variant tints everything gold. A cooled meteor is dull grey #68646A.

**Hook:** `ServerStorage.Assets.Meteor.Core` and `ServerStorage.Assets.NodePieces` are the templates `MeteorService:_spawnMeteor` clones. Replace their parts with these meshes and keep the names `Core`, `Vein` and `NodeSlot`.

### 5d. Minerals (12, optional): `meteor/minerals/<id>.fbx`
- These are collectable gems shown in the Mineral Index. Today the Index uses 2D icons, so these are optional, and their renders could become the icons.
- About 1.5 studs each. Single object, glossy, faceted, with a recognisable silhouette.

| Id | Name | Colour | Shape |
|---|---|---|---|
| magnetite | Magnetite | #969CB0 | A dark metallic octahedron cluster |
| hematiteRose | Hematite Rose | #D6544C | A rose of curved metallic petals |
| meteoricNickel | Meteoric Nickel | #D6DAC4 | A pitted pale nugget with a cross-hatch pattern |
| starfallIron | Starfall Iron | #FFA040 | A star-shaped glowing iron nugget (rare: add a *neon* centre) |
| rimePearl | Rime Pearl | #E2F0FA | A frosty pearl in a small ice cup |
| frostOpal | Frost Opal | #8CE8E2 | A smooth oval opal with a swirl |
| glacialSapphire | Glacial Sapphire | #4888F0 | A tall hexagonal sapphire prism |
| heartOfWinter | Heart of Winter | #96F6FF | A heart-shaped ice crystal (rare: *neon* core) |
| prismShard | Prism Shard | #FFC4F0 | A triangular prism shard |
| amethystSpire | Amethyst Spire | #AC68E8 | A cluster of three amethyst spires |
| resonantQuartz | Resonant Quartz | #FF78CE | A double-terminated quartz with ring grooves |
| voidDiamond | Void Diamond | #965CFF | A dark violet diamond with a starry *neon* inner core (rare) |

---

## 6. Ore, bars and currency items (`items/`)

These are small items used in effects, the refinery, the Trading Post and shop previews.

| File | Size | Look | Objects |
|---|---|---|---|
| `ore_iron`, `ore_frost`, `ore_crystal`, `ore_alien` | ~1.2 | Raw ore lumps in the four ore colours (see the meteor table). Iron is metallic and rough, frost is an icy cluster, crystal is pink spikes, alien is a green glowing blob. | `Ore` (tint) |
| `bar_iron`, `bar_frost`, `bar_crystal`, `bar_alien` | 2 × 0.8 × 1 | A classic trapezoid ingot with bevelled edges and a stamped meteor logo on top. One object per ore type, coloured with that ore's colour. | `Bar` (tint) |
| `bar_stack` | 4 × 2 × 3 | A pyramid of six gold bars (3, 2, 1), for the Trading Post counter and the "sell" visual. | `Bars` |
| `coin` | 2 × 2 × 0.3 | A thick gold coin with a raised rim and a "$" on both faces. | `Coin` |
| `core_shard` | ~1.4 | The Core Shard currency (used to hatch eggs): a glowing blue-violet crystal shard with a gold base clasp. | `Shard` (neon), `Clasp` |

---

## 7. Debris rocks (`rocks/`)

These are the mineable rocks in the four ore fields: 48 in the map, 12 per field.

**Rules**
- **The footprint must stay within 8 × 8 studs.** The aisles between rocks are fixed at 14 studs.
- About 5 to 7 studs tall, pivot at the bottom centre.
- Objects:
  - `Root`: the rock body; it becomes the mined part. Its colour is mixed toward the field colour at runtime, so model it in the given body colour.
  - `RockChunk`: an optional cap or side lumps, never tinted.
  - `OreFleck`: 2 or 3 crystal flecks on top, *tinted* by difficulty tier, *neon*, plain white.
- Three variants per biome (a, b, c), so the 12 rocks don't look identical.

| Biome (field) | Files | Look |
|---|---|---|
| Rust Works (rusty quarry, NW) | `rock_rust_a/b/c` | Chunky stepped rust-red boulders (rust ramp) with flat ledges and a few bolted iron plates. Flecks are orange. |
| Frost Yard (snow, NE) | `rock_frost_a/b/c` | Icy blue blocks (frost ramp) with snow caps on top and icicles on the edges. Flecks are pale cyan. |
| Violet Quarry (crystal, W) | `rock_violet_a/b/c` | Dark navy stone (navy ramp) split by violet crystal veins. Flecks are violet. |
| Sulfur Ridge (volcanic, E) | `rock_sulfur_a/b/c` | Pale yellow-grey porous stone (stone and sulfur ramps) with yellow crust patches and small vent holes. Flecks are gold. |

**Hook:** `tools/map-v2/DebrisFields.luau`. Roots must stay `BasePart`s with the `Field` attribute. `DebrisService` tints only children named `OreFleck`.

---

## 8. Map hero pieces (`map/`)

These are big unique landmarks. The map stages already look for these names in `ServerStorage.MapArt` (through `T.mesh`) and fall back to parts when one is missing.

**The map allows at most 12 MeshParts in total** (`tools/map-v2/StaticQA.luau`). Keep each hero piece to the objects listed below, and raise that limit if more are wanted.

| Name | Where | Size (W × H × D) | Look | Objects |
|---|---|---|---|---|
| `Anvil` | By the Gear Hall door | 5 × 3.5 × 2.5 | A classic blacksmith anvil: dark iron (navy ramp) with a pointed horn, a flat face, a stepped waist and a wide foot, on a tree-stump block (wood ramp). A small orange glowing hot ingot sits on top (*neon*). | `Anvil`, `Stump`, `HotIngot` (neon) |
| `GiantEgg` | Hatchery roof | 16 × 22 × 16 | A huge cartoon egg: a cream shell with pastel pink and teal spots, and a zig-zag crack band near the top through which a soft glow shows. It sits in a straw nest ring. | `Shell`, `Spots`, `CrackGlow` (neon), `Nest` |
| `Trophy` | The top step of the north "1-2-3 TOP MINERS" podium | 4.5 × 6.8 × 4.5 | A gold cup trophy: a two-handled bowl, a stem, a dark square base with a star emblem, and a small pickaxe crossed over the cup. | `Cup`, `Base` |

Optional heroes, for when the MeshPart limit is raised:
- `CrossedPickaxes`: two giant crossed pickaxes for the Gear Hall roof, 14 × 12 × 2. Wooden handles, steel and light-blue heads, gold heads on the reverse.
- `GoldCoinSign`: the giant coin on the Trading Post roof, 9.6 wide. It can reuse `items/coin` scaled up.
- `RebirthPortal`: a gold ring 22 studs across with five white accent bands, on a gold foot. The inner disc stays a Roblox part (it glows).
- `MeteorStatue`: "THE FIRST METEOR", north of the crater. A 15-stud dark navy meteor boulder with orange-gold glowing cracks, half sunk in a small stone crater bowl 19 studs across, with a curved flame trail rising behind it.
- `Telescope`: the Meteor Watch observatory telescope, 11 long, in brass and gold with a dark eyepiece.
- `RefineryChimney`: a red and white striped chimney stack, 4 × 14 × 4, with a smoke cap.
- `Crane`: the Rust Works orange gantry crane, 52 × 28 × 5, with a trolley and a hanging ore bucket.
- `IceCave`: the Frost Yard ice cave arch, 36 × 25 × 9, with icicles and a snow cap.
- `CrystalCluster`: the Violet Quarry landmark, 30 × 34 × 12. Five glass-like violet crystal spires with pink tips on a dark plinth.
- `SulfurVent`: a volcanic vent cone, 12 × 13 × 12, with a yellow crust and a glowing top. Used three times.
- `Snowman`: 7 × 17 × 7, with a scarf, top hat and carrot nose.

---

## 9. Repeated props (`props/`)

These are placed many times. They are only worth turning into meshes if the MeshPart limit is raised. Each one replaces 3 to 8 parts, so the part count goes down. Keep each to one or two objects.

| Name | Size | Look |
|---|---|---|
| `tree_round` | 11 wide × 16 tall | A cartoon tree: a short wood trunk and three overlapping canopy balls in green light, body and dark. |
| `tree_pine` | 12 × 18 | Three stacked rounded cones (dark and body green) with a small ball on top. |
| `bush` | 7 × 5 | Two overlapping rounded leaf balls; one variant has pink flowers. |
| `lamp_post` | 3 × 13.5 | A dark round base, a thin ink pole and a round glowing lantern (`Lantern`, neon warm glow). |
| `bench` | 8 × 4.5 × 3 | A rounded wooden seat and back on ink legs. Back and seat tinted, so it can be red or blue. |
| `crate` | 4.6 cube | A wooden crate with darker cross bands. |
| `barrel` | 4.2 × 5 | A wooden or painted barrel with two ink bands and a lid. |
| `planter` | 10 × 4 × 4.5 | A cream box planter with a white lip and three or four ball flowers in pink, gold, red and white. |
| `banner` | 5 × 18 | An ink pole with a gold ball tip and a hanging cloth banner (`Cloth`, tint). |
| `sack` | 3.4 | A cream grain sack tied at the top. |
| `mine_cart` | 6 × 4.5 × 4.4 | A stone-grey mine cart with an orange rim on small wheels, ore heaped inside. |
| `fountain` | 40 diameter × 20 | The town fountain: a cream plinth, a blue pool wall, a white rim, a two-tier gold bowl centrepiece and a glowing spout. The water stays a Roblox part. |
| `turret` | 24 diameter × 50 | A boundary corner turret: a red round tower, a white band, a stone lip, a stepped navy cone roof, a gold knob and a gold pennant. |

---

## 10. Not for Blender (for reference)

- **HUD icons** are 2D PNGs in `assets/hud/` (coin, crystal, ore, bars, backpack, equipment and so on). The 512 px previews from the rules above can replace the equipment, pet, egg and mineral icons if wanted.
- **Effects** (meteor streak, shockwave, sparkles, smoke, dust) are Roblox particles and parts, so no meshes are needed.
- **Ground, roads, crater bowl and boundary walls** stay as Roblox parts with stud textures, because they define collision and paths.
- **Signs** stay as Roblox parts, so their text can be edited in the game.

## Summary count

| Group | Assets | Files |
|---|---|---|
| Pickaxes | 8 | 8 |
| Backpacks | 8 | 8 |
| Pets | 14 × 2 looks | 28 |
| Eggs | 3 | 3 |
| Meteor (core, 4 node pieces, ore chunk) | 6 | 6 |
| Minerals (optional) | 12 | 12 |
| Items (ores, bars, stack, coin, shard) | 11 | 11 |
| Debris rocks | 4 biomes × 3 | 12 |
| Map heroes (3 required, 11 optional) | 14 | 14 |
| Repeated props | 13 | 13 |
| **Total** | | **115** |

Suggested order, by impact:
1. Meteor core and node pieces.
2. Pickaxes T1 to T3 and backpacks T1 to T3, which new players see first.
3. The four Common and Uncommon pets, which are 83% of Meteor Egg hatches.
4. The three eggs.
5. The debris rocks.
6. Everything else.
