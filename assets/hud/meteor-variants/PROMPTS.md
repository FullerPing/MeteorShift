# Meteor variant image generation prompts

The three recolour calls used the built-in `image_gen` tool with `assets/hud/meteor.png` as the reference and `transparent_background = true`. No CLI was used. The shared prompt below is verbatim; the three palette sections are retained colour specifications from the call summary, not verbatim suffix wording.

## Shared prompt — verbatim, used for all three calls

```text
Use case: precise-object-edit. Edit target: the supplied existing MeteorShift meteor HUD icon. This is a RECOLOUR ONLY of its exact artwork. Preserve its faceted rock silhouette, diagonal down-right direction, all existing triangle polygons, orange/yellow speed-trail shapes and positions, the two rounded detached motion streaks, existing line widths, dark charcoal outlines, flat vector-like rendering, square canvas, padding and proportions. Do not redraw, add shapes, add crystals/icicles/faces/text/symbols, change perspective, or add gradients, glow, 3D shading or a background. Keep the original original dark outlines dark charcoal; change only the coloured fills to the requested palette. Render one isolated icon on a genuinely transparent alpha background, no checkerboard baked into the image, no labels or watermark. Match the original icon exactly so it belongs to the same HUD family.
```

## Crystal — retained colour specification

Output: `meteor-crystal.png`. Use the shared prompt with this purple palette:

| Fill | Colour |
|---|---|
| Rock | `#7850C8` |
| Shadow | `#4A2E7F` |
| Light facet | `#B592EE` |
| Trail / seam | `#BA86FF` |
| Streak | `#EAD0FF` |

## Ice — retained colour specification

Output: `meteor-ice.png`. Use the shared prompt with this cyan palette:

| Fill | Colour |
|---|---|
| Rock | `#75CFF4` |
| Shadow | `#328DB9` |
| Light facet | `#D7F5FF` |
| Trail / seam | `#A4EAFF` |
| Streak | `#E9FCFF` |

## Alien — retained colour specification

Output: `meteor-alien.png`. Use the shared prompt with this mint palette:

| Fill | Colour |
|---|---|
| Rock | `#73DEB4` |
| Shadow | `#279C7B` |
| Light facet | `#C7FFE8` |
| Trail / seam | `#96F4CF` |
| Streak | `#DDFFF0` |
