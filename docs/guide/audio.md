# Audio and reward effects

All sounds are licensed for every Roblox experience. They are uploads by Roblox's library accounts: **ProSoundEffects** (Pro Sound Effects SFX), **APMOfficial** (APM music and stings) and Roblox's own UI kit (`Roblox_UI_*`). Never use Creator Store re-uploads by other users: they are often ripped from other games.

To find more, search the Creator Store toolbox and keep only results whose creator is `ProSoundEffects` or `APMOfficial`:
`https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&query=<words>&maxPageSize=100`

## Where things live

| What | File |
|---|---|
| Sound ids, volume, pitch, cooldown, group, variants, music ducking | `src/shared/Config/Sounds.luau` |
| Music tracks, ambience, crater hum, warning timing | `src/shared/Config/Music.luau` |
| Playback, SoundGroups (Master > Music, Ambience, SFX, UI), Settings mutes | `src/client/Sfx.luau` |
| Music crossfade, ambience, crater hum, meteor siren, core-crack sting | `src/client/Controllers/MusicController.luau` |
| Sounds and bursts for deposits, upgrades, evolves, level ups, pets, bonuses, refusals, menus, tutorial | `src/client/Controllers/FeedbackController.luau` |
| Reward effects (ground ring, light pillar, confetti, puff, coin flight, pop text, crit kick) | `src/client/RewardFX.luau`, `src/shared/Config/RewardFX.luau` |
| Particle sprites (sparkle, ring, rays) | `assets/fx/`, drawn by `tools/store-art/draw_fx_sprites.py` |

The other hooks are in these controllers:
- **MiningController:** swing whoosh, crit clang and kick, ore pickup pop that climbs in pitch, vein bonus.
- **HatchController:** shell ticks, crack, a reveal sound by rarity, rays and shell shards.
- **RebirthController:** warp and fanfare, a big pillar with confetti.
- **FieldTravelController:** teleport whoosh and puffs.
- **PerksController:** perk bought.
- **HUDController:** sale coins flying to the wallet.

## Settings

The **Music** and **Sound effects** switches set the player attributes `MusicOn` and `SfxOn`. Music mutes the Music and Ambience groups. Sound effects mutes the SFX and UI groups.
- **Reduce effects** skips every RewardFX visual, the hatch rays and the hatch shards.
- **Reduce camera shake** skips the crit kick.

## Current picks

| Name | Asset | Source title |
|---|---|---|
| Hub music | 1837464887 | APM "Tropical Island" |
| Event music | 9040031590 | APM "Level Up (Alternate 3)" |
| Ambience | 9112832288 | PSE "Mountain Birds 1" |
| Crater hum | 9112824733 | PSE "Low Rumble 2" |
| LevelUp | 1842335078 | APM "Cartoon Fanfare (c)" |
| Evolve | 1842141543 | APM "Victory Lap (sting)" |
| Rebirth | 1844584698 | APM "Winner" |
| RevealLegendary | 1845411858 | APM "Top Prize" |
| CoreStinger | 133000497392138 | APM "Kinetic Victory (Sting)" |
| MenuOpen / MenuClose / Deny / TutorialStep / OrePickup / BackpackFull | 15675028888 / 15675012262 / 15675075163 / 15675043410 / 15675055424 / 15675062723 | Roblox UI kit |

Everything else is Pro Sound Effects (titles at `https://create.roblox.com/store/asset/<id>`). To swap a sound, change its id in the config. `tests/Sounds.spec.luau` checks the shape of each entry.
