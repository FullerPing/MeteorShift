# Pets: roster and art direction

14 pets in six rarities. Rarer pets have more and stronger explicit perks and look better: more parts, glow, trails and idle animation. The two paid pets (game passes, fixed price, never random) are the best looking and the strongest miners. Rules and numbers are in `Config.Pets`; this file is the art brief.

## How you get them

- **Meteor Egg**, 30 Core Shards: Common 55%, Uncommon 28%, Rare 12%, Epic 4.5%, Legendary 0.5%. Guaranteed Epic or better every 30th hatch.
- **Crystal Egg**, 120 Core Shards: Uncommon 38%, Rare 40%, Epic 18%, Legendary 4%. Guaranteed Epic or better every 12th hatch.
- A duplicate gives 400 XP to the pet you already own.
- **Drillbot** (99 Robux) and **Solar Phoenix** (199 Robux) are game passes: fixed price, not in any egg.
- Shards can only be earned in play, so no Robux purchase changes any odds (spec §9.4). The odds are shown on the egg cards.

## Perk rules

Every pet's first perk is its main role. Values grow linearly between the exact level 1 and level 10 endpoints below; pet XP, duplicate XP, eggs and pity retain their existing rules. Equipped pets add their values per role, then apply that role's cap. Rarity gives Common and Uncommon one perk, Rare one or two, Epic two, and Legendary and Premium three.

| Role | Effect | Equipped cap |
|---|---|---|
| Miner | This share of pickaxe Mining Power and ore, only within 15 seconds of your validated swing; ore goes to the hopper | 100% |
| Hauler | This share of current backpack capacity moved to the hopper each second | 6% |
| Pack | More backpack capacity | 60% |
| Swift | Shorter swing time | 30% |
| Merchant | More cash from selling bars | 45% |
| Yield | More ore from each validated player hit | 40% |
| Sprint | More walk speed from base 16, without overriding other speed changes | 30% |
| Vault | More hopper and collection post capacity, online and offline | 100% |
| Crit | Added percentage points of pickaxe critical-hit chance | 15 points |
| Scholar | More player XP from every source, through `LevelService:AddXp`; pet XP is unchanged | 60% |
| Shards | More total Core Shards when a core cracks, rounded down after multiplication | 30% |

Miner hits never count toward the podium, core rewards, mineral drops or meteor size. Yield, Scholar and Vault preserve fractions for their existing consumers; Shards rounds the whole payout once. No perk changes mineral or egg odds.

Slots start at one and gain one per rebirth up to three. The fixed 49 Robux ExtraPetSlot pass adds one after that cap, for two to four slots depending on rebirths. Its ownership is checked by the server.

For each role that appears at a rarity, its strongest level 10 value never falls as rarity rises; rarities without that role are skipped. Paid pets beat free pets at level 10 for every role they share. Drillbot's starting Swift value ties Jet Wisp at 8%, then grows higher.

## Look rules for every pet

- Under 300 parts (Premium and Legendary may use up to 400), no colliders, unanchored, no scripts.
- A `Body` part and a `PetColor` attribute (`Config.Pets.List[...].Color`) for tinting.
- Level 1 and level 10 looks: the level 10 pet adds accent trim, extra glow, slightly larger parts.
- Rarity ladder for visuals: Common is plain and matte with one accent colour; Uncommon adds a second material and a small animated part; Rare adds a glow or particle; Epic adds a trail, an emissive crystal or a halo; Legendary adds all of that plus a light and a spawn flourish; Premium is the best of everything: unique materials, constant effect, a signature idle animation and a hatch/summon effect.
- Pets follow at the owner's shoulder or heel (ground pets trot, flyers hover) and play a short "working" animation when their perk fires.

## Common (grey name)

**Pebble Pup**. A knee-high pup assembled from rounded grey pebbles: a big boulder body, a smaller pebble head, stubby pebble legs and a tail made of three stacked stones. Two dark pebble eyes, no glow, matte stone. It trots at your heel; when it mines it digs with both front paws and a few grey chips fly.

**Perks, level 1 to level 10:** Yield 5% to 10%.

**Scrap Sparrow**. A small sparrow stitched from tan scrap metal plates, one mismatched bolt-eye, a rusty copper beak and a tail of three spring-loaded flaps. It sits on your shoulder and chirps a metal "ting" when you sell bars.

**Perks, level 1 to level 10:** Scholar 8% to 16%.

## Uncommon (green name)

**Pack Mule**. A compact robot mule, sandy tan, grey head with one floppy ear, a short bristle mane and two side panniers with buckles. The panniers grow bigger at level 5 and level 10 to match the extra space. It trots behind you with a gentle bob.

**Perks, level 1 to level 10:** Pack 15% to 30%.

**Spark Hare**. A long-eared hare in warm yellow fur, cream belly, big dark eyes, with blue-white sparks crackling along the ear tips and paws. It bounds in small hops beside you; when you swing, its ears flick and a spark jumps to your pickaxe.

**Perks, level 1 to level 10:** Swift 5% to 12%.

## Rare (blue name)

**Jet Wisp**. A glowing cyan teardrop spirit with a white core, two soft eyes and twin wispy flame tails. It floats and bobs above your shoulder leaving a faint cyan trail; when you swing it flares bright for a frame.

**Perks, level 1 to level 10:** Swift 8% to 18%; Sprint 6% to 15%.

**Coin Magpie**. A black and white magpie with a green-gold sheen on the wing and a long tail, carrying a gold coin in its beak. It perches on your shoulder, hops along the ground when you stand still, and a coin glint flashes when you sell bars.

**Perks, level 1 to level 10:** Merchant 8% to 20%.

**Cargo Mole**. A chubby round mole, dark brown, with a pink nose, tiny pink claws and sleepy eyes. It wears a small yellow hard hat with a dim lamp and a canvas satchel on its back. It waddles behind you; when it hauls, a small ore chunk hops out of the satchel and arcs toward your hopper.

**Perks, level 1 to level 10:** Hauler 1.2% to 3%; Pack 8% to 18%.

**Granite Golem**. A knee-high boulder golem built from charcoal granite blocks: blocky torso, small head with two glowing amber eye slits, big fists, and a moss patch on the shoulder. A hatch in its chest glows when your backpack is nearly full. It walks heavily behind you, each step with a faint thud.

**Perks, level 1 to level 10:** Pack 20% to 38%; Vault 25% to 60%.

## Epic (purple name)

**Crystal Stag**. A slender deer of violet crystal, translucent legs, a pale pearl underbelly, and antlers of branching glowing amethyst. A soft purple glow and sparkles trail it. When it mines it lowers its head, the antlers flash, and crystal shards burst from the target.

**Perks, level 1 to level 10:** Crit 4% to 10%; Miner 12% to 25%.

**Lode Wyrm**. A long burrowing worm, segmented in warm copper plates with glowing amber seams, a blunt armoured head with a ring of tiny drill teeth and two bright eyes. It coils beside you above the ground; when it hauls it dives into the rock and a trail of glowing ore chunks races along a tunnel of light toward your hopper, then it pops back up. It sheds a faint orange glow and tiny sparks as it moves.

**Perks, level 1 to level 10:** Hauler 1.5% to 3.75%; Vault 35% to 80%.

**Aurora Owl**. A large owl with teal and mint feathers that shift colour through an aurora gradient, wide golden eyes and a ribbon of green light streaming from its wings. It hovers over your shoulder; each sale sends a ripple of aurora colour across its feathers.

**Perks, level 1 to level 10:** Merchant 12% to 28%; Shards 6% to 15%.

## Legendary (gold name)

**Meteor Drake**. A small dragon about as big as a dog, charcoal scales with glowing orange cracks like cooling lava, ember-tipped horns, a heavy tail that drags a trail of sparks and tiny wings that leave embers. Its eyes burn white-hot. When it mines it breathes a short flame and slams the rock with its tail. It carries its own warm point light, and arrives with a meteor-streak and flash when hatched.

**Perks, level 1 to level 10:** Miner 22% to 36%; Yield 8% to 18%; Shards 8% to 20%.

## Premium (pink name, game passes, best of everything)

**Drillbot**. A polished steel drone with an orange hazard stripe, a glowing amber eye-lens, a spinning drill nose and two rotor fins. It hovers at your shoulder with a soft hum. When it mines the drill spins up with a spark fountain and a heat shimmer. At level 10 it gains gold trim, bigger rotors and a blue engine glow. It spawns in with a short assemble animation, parts clicking together.

**Perks, level 1 to level 10:** Miner 25% to 40%; Swift 8% to 20%; Yield 10% to 20%. Fixed game pass: 99 Robux.

**Solar Phoenix**. A phoenix of molten gold and white fire: a long flowing tail of layered flame feathers, a crown of rays above its head, and wings that spread slightly as it hovers. A constant warm light, a trail of gold sparks and a slow rotating halo ring. When it mines it dives at the target and bursts into a ring of sunlight, then returns to your shoulder. It leaves a faint scorch glow on the ground when it lands. It is unique to this pass; no other pet has a halo.

**Perks, level 1 to level 10:** Miner 50% to 100%; Merchant 15% to 35%; Scholar 15% to 35%. Fixed game pass: 199 Robux.
