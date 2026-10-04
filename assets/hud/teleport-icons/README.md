# Teleport icon choices

Seven standalone 64 × 64 SVGs with transparent backgrounds, `currentColor`, and rounded 4 px strokes. No fonts, embedded images, filters, scripts or external dependencies.

- `teleport-portal.svg`: arrow entering an oval portal; recommended for the HUD.
- `teleport-warp.svg`: directional warp arrow with a small destination sparkle.
- `teleport-pad.svg`: a person dissolving above a teleport pad.
- `teleport-linked.svg`: two portals connected by an arrow.
- `teleport-blink.svg`: a blink burst inside four destination corners.
- `teleport-pad-refined.svg`: stronger person silhouette, an arched energy field and a shallow pad.
- `teleport-warp-refined.svg`: a single closed arrow and two departure streaks, with more open space.

Set the SVG's CSS `color` when used inline. For Roblox raster export, replace `currentColor` with white and tint the uploaded image through `ImageColor3`. The PNG comparison is a preview, not a game asset.

The intended HUD button has the icon above a separate, centered `TELEPORT` TextLabel. Match existing navigation: `Enum.Font.GothamBold`, white text, dark RGB(17, 24, 28) text stroke with transparency 0.25, and the caption occupying the bottom 30% of the button. Keep text out of the icon SVG.

At the desktop 88 px button size, use 16 px text; Studio measures `TELEPORT` at 76 px wide. Touch navigation currently draws 24 px base text at 0.5 scale (12 px on screen): `TELEPORT` measures 56.5 px, so give its caption at least 64 px of width and reserve that spacing when integrating the button. A 44 px touch caption would overflow. These assets do not add a button to the game.

`preview.png` shows the original five variants; `preview-more.png` shows linked portals and the blink burst; `preview-refined.png` shows the refined pad and warp designs. The preview raster uses the bundled Montserrat Bold font for the visual sample; the production label must use the existing native `GothamBold` enum specified above.
