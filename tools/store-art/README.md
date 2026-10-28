# Store art (icon, 5 thumbnails, loading backdrop)

2D vector art drawn in code (SVG strings, rasterised by sharp). No Blender, no Studio captures.

```
node tools/store-art/build.cjs all        # t3 t2 icon t1 t5 t4 loading
node tools/store-art/build.cjs t3         # one piece
python tools/store-art/smalltest.py       # review sheets in assets/marketing/v2/preview/
```

- `lib/type.cjs` Fredoka One outlines (copied from `tools/key-art/typography.cjs`; needs `.tmp/craterworks-opentype.cjs` and the sharp path hard-coded in it)
- `lib/shapes.cjs` glossy primitives (ink outline, lip, shine), arrows, ribbons, pills, coins, bars, clouds
- `lib/art.cjs` Meteor Egg, pedestal, Meteor Drake; `lib/hero.cjs` meteor, pickaxes (tiers 1/4/6/8), the Miner; `lib/scene.cjs` sky, Meteor Peak, rampart, crater
- `lib/raster.cjs` renders at 2x, adds a bloom layer (blurred, screen blended) and a vignette, downsamples
- `pieces/*.cjs` one file per deliverable. Output goes to `assets/marketing/v2/`.

The wordmark (`v2/wordmark*.png`) and loading `cloud.png`/`trail.png` come from `tools/key-art/typography.cjs` and are reused as is.
