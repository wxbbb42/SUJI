# Native design QA — Figma reference refinement

Date: 2026-09-19. Target: the four existing SwiftUI tabs and onboarding. No website was scaffolded.

## Source and comparison method

- Source: [Figma node 1:17](https://www.figma.com/design/Nk1dbVHGGPwvg0JwjxS5v6/Untitled?node-id=1-17), read with official `get_design_context` and `get_screenshot`.
- Local source: `Documentation/figma-reference.jpg`; original capture `artifacts/figma-reference.png` (2200 × 1293; Figma natural canvas 4006 × 2354).
- The node is a moodboard of five raster references, not a SUJI layout specification. Its apps have different content and states. QA compares the requested art direction and hierarchy rather than asserting pixel identity between unrelated products.
- Full-view comparison: `Documentation/design-comparison.jpg`, with the captured moodboard and actual native Today/Chat/Calm/Profile screens in the same image.
- Standard implementation: iPhone 17 Pro, 402 × 874 logical points, screenshots 1206 × 2622 at 3×, normalized to 450 × 978 each in `Documentation/overview.png`. All are portrait and normal text size; calendar date is actual device date.
- Small implementation: iPhone 17e, 390 × 844 logical points, screenshots 1170 × 2532 at 3×. Dark/accessibility captures use `UICTContentSizeCategoryAccessibilityXXXL` and Reduce Motion.

## Comparison history

1. Inspected the reference and pre-refinement native screens. Native flow was functional, but the visual direction lacked botanical imagery, Calm used a different Chinese heading treatment, and the profile's long joined traits had excessive display emphasis. Updated shared paper/ink tokens, bundled original botanical art, applied the real Chinese serif font to Calm, simplified chat hierarchy and used native segmented mode selection.
2. Captured six passing standard-device flows in `/tmp/suji-figma-ui-final.xcresult`; reviewed full combined comparison and full-resolution profile. **P2: profile hierarchy** — short traditional classifications and long personal observations still shared the same display treatment, making the first screen read as several disconnected headings. Moved secondary traits into the existing “多了解一点” disclosure, leaving the primary observation and readable description visible.
3. Reviewed small-device normal dark botanical and accessibility contact sheet. **P2: accessibility header compression** — the decorative profile seal squeezed the title into an ellipsis at AX XXXL. **P2: send-icon overflow** — the dynamically scaled SF glyph exceeded its fixed 48 pt button. Hid the decorative seal for accessibility sizes, let the title/subtitle/date grow vertically, and fixed the functional glyph at 20 pt while preserving its 48 pt target.
4. The focused profile/breathing and extended accessibility journeys passed on both devices in `/tmp/suji-figma-profile-final.xcresult`. Final recapture after both accessibility fixes passed on both devices in `/tmp/suji-figma-accessibility-final.xcresult`. `Documentation/accessibility.png` shows the full title, contained send glyph, normal-dark illustration and scrolled populated profile. No actionable P0/P1/P2 remains.

## Required fidelity surfaces

| Surface | Evaluation |
| --- | --- |
| Typography | Bundled Noto Serif SC supplies Chinese editorial titles; SF system text supplies controls/body. Custom text scales with Dynamic Type. Calm now uses the same title family. Profile's secondary terminology is expandable. The post-fix profile was recaptured on both devices; primary observation and lower navigation are clear. |
| Spacing and layout | 24–26 pt content insets, generous editorial gaps, slight paper corner rounding, thin rules, restrained shadow. One breathing focus. Native tabs and input composer remain attached to safe areas. Large-type scroll reachability is exercised by UI tests. |
| Color and tokens | Cream `#F6F3EC`, paper `#FFFDF8`, olive ink `#29352D`, sage interactive tint and sparing vermilion seals. Celadon and dark palettes remain adaptive. Decorative contrast is subordinate to text contrast. |
| Imagery | Original Azure GPT Image 2 ginkgo in local asset catalog; 363 × 768 RGBA. Aspect-fit at each callsite, never stretched or used as a screen background. Full branch and transparent edges inspected on paper/ink. It is hidden in Today/Chat at accessibility sizes. No Figma app screenshot or device chrome is shipped as UI. |
| Copy and content | Existing SUJI self-care flows retained. Editorial daily content is labeled; real provider configuration failures stay visible; synthesized ambience is accurately identified. No reference-product labels, lorem ipsum or design instructions appear in the app. |

## Interaction and accessibility evidence

- Native NavigationStack, TabView, segmented controls, Form, sheets, menus, share sheet and keyboard avoidance.
- Actual paper drag returns below threshold and completes above threshold; reveal button supports reduced motion and accessible operation.
- Journal/history/share, real sound playback, breathing pause/stop, birth/profile/charts and missing-AI-configuration recovery passed on the standard simulator.
- Small-device dark, celadon and accessibility screenshots were opened and reviewed. `Documentation/accessibility.png` verifies the title and send-button fixes; the input remains hittable and birth save/profile navigation passes at AX XXXL.

## Remaining findings

- No open P0/P1/P2 findings. Profile hierarchy and both accessibility defects are closed by post-fix captures and runtime tests.
- No placeholder illustrations, substituted device chrome or broken primary controls were observed in the reviewed standard screenshots.

## Focused comparison evidence

Full-resolution `artifacts/final/11-profile.png` and the final four-screen overview were inspected for Chinese typography, hierarchy and wrapping. `Documentation/accessibility.png` provides enlarged interface details at both normal dark and AX XXXL states. `artifacts/botanical-alpha-review.png` compares the actual RGBA image over paper and ink, and `Documentation/ritual-curl-strip.png` shows real continuous motion frames. These focused views complement the final combined moodboard/render image rather than relying on a reduced overview alone.

## Follow-up limits

The source is a moodboard, so different SUJI text, exact screen geometry, SF Symbols and native iOS 26 navigation are intentional. Large-type screens scroll naturally rather than shrinking text. Physical-device performance, haptics, audio quality and live service delivery remain outside simulator visual QA; see `VERIFICATION.md`.

final result: passed
