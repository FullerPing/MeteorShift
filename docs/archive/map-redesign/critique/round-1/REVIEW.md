# First visual pass — partial, not an accepted critique round

6 October 2026. A new Studio connection, `855dc0ff-1333-4ce9-bced-616b9099ef09`, confirmed that the saved map and inactive lighting profile survived reopening. Screenshot capture initially worked in this session. The screenshots use the temporary daylight profile; original Lighting must be restored before saving. Meteor and equipment are static art previews, not live gameplay or local-player state.

Six native JPEGs were saved. `captures.json` records camera positions and hashes for the five close views. `overview-before-previews.jpg` shows the daylight overview before the static meteor/equipment were added. The Trading Post camera was inside the refinery and obscured the counter; that image cannot verify its full appearance. Rebirth capture then failed. This set does not cover every zone and counts as **zero completed critique rounds**.

Scores below are provisional visual assessments of the images actually inspected. Performance is unmeasured and has no quality score. Missing zones receive no invented scores. All nine categories still need the full required coverage and runtime evidence before acceptance.

| View | Silhouette | Colour | Studs | Scale | Density | Signage | Navigation | Reward feel | Performance |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Overview | 3 | 4 | 2 | 3 | 2 | 2 | 3 | 3 | Unmeasured |
| Refinery | 3 | 4 | 3 | 3 | 2 | 2 | 3 | 3 | Unmeasured |
| Gear Hall | 3 | 3 | 2 | 3 | 3 | 2 | 3 | 3 | Unmeasured |
| Hatchery | 3 | 4 | 3 | 2 | 2 | 2 | 2 | 3 | Unmeasured |
| Spawn plaza | 3 | 4 | 2 | 3 | 2 | 2 | 3 | 3 | Unmeasured |

Observed problems and the first repairs:

- The refinery front was mostly a blank housing, and its conveyor was embedded in the housing. Added a 22×18 glowing furnace mouth with metal frame/grille; shifted the reused conveyor using its actual bounds to a front edge of Z−348.4. The service sign moved below the mouth. UsePoint and the foundation did not move.
- Fixed world-sign canvases used the same aspect ratio for every board and left headings small or stretched. Match CanvasSize to each physical sign face. Internal ScreenGuis and their controllers remain frozen.
- Gear Hall's current-display boards concealed equipment shafts/bodies. Lowered them below the display tops. Outer tier cards also clipped the side walls; narrowed/re-spaced all sixteen and rebuilt the temporary art previews. Added two cheap shadow-free fill lights for the dark interior. Live state/rotation still requires the gated controller.
- Hatchery's large odds boards hid its eggs. Expanded the staged footprint from100×72 to128×72 and put each egg beside its unchanged Config-derived odds board. Its east edge remains14studs from the spawn spine. Adjusted tree clearance and layout.svg accordingly.

After-fix screenshots are still needed. The broad boundary silhouette, sparse spawn treatment, stud consistency and wayfinding also need further inspection/repair. Crater, roads, Trading Post, Rebirth, museum, all four debris yards and boundary have no accepted close-view critique yet. Do not claim three rounds, two consecutive4+ rounds, performance acceptance, live equipment or gameplay QA from this file.

The owner's frozen GUI preview obscures parts of the Edit captures: a white upper-left block, a large currency card and right-side navigation. This is an observation of Edit preview only, not proof of a runtime GUI bug. Report any corresponding runtime issue after the required Play/phone checks; do not alter the frozen GUI to clean up screenshots.

Native capture recovered after the save brought Studio to the foreground. refinery-after-original-lighting.jpg confirms the furnace mouth and exposed conveyor with original17.2lighting and no previews. It is cropped and does not replace a full after-fix daylight view. Full-zone coverage and all acceptance rounds remain pending.

Continuation on6October: gallery now13JPEGs. Spawn frames/studs and sign outline are clearer; its grey crest blended into the wall and was changed orange (final image pending). Gear interior has clearer boards but live equipment is still gated. Side-by-side hatchery eggs are visible; odds type increased28→44 after small text/initial blank left board. The final odds44image shows both text blocks; readable phone/close-player/daylight checks remain pending. TextService verified exact fit, not gameplay. A wrong Trading camera inside Gear Hall is marked unusable; trading-post-corrected.jpg is a clear booth view. Other missing zones/performance prevent an accepted round. All additional images use original17.2lighting and no previews, so do not compare colours as a final daylight pass.
