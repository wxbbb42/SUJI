# Botanical artwork

`Assets.xcassets/Ginkgo.imageset/ginkgo.png` is an original illustration generated for this project with the user's configured **Azure GPT Image 2** deployment on 2026-09-19. It is bundled locally and makes no runtime network request.

The user supplied a [Figma moodboard](https://www.figma.com/design/Nk1dbVHGGPwvg0JwjxS5v6/Untitled?node-id=1-17) with five references: a traditional-hours app, a literary quote card, a botanical reading app, a typographic paper poster and a botanical learning app. Their cream paper, restrained natural color and editorial whitespace informed the native design. The reference screenshots are not shipped as app artwork.

The complete generation prompt is in `Documentation/botanical-prompt.txt`. The moodboard was passed as a style reference. GPT Image 2 produced a 1024 × 1536 PNG on a white background; local image processing removed that background, retained the full branch, and reduced the result to 363 × 768 RGBA (about 182 KB). Transparency was inspected on warm paper and deep ink backgrounds.

`SujiBotanical` uses aspect-fit rendering in the onboarding, daily calendar and empty-chat headers. The daily/chat ornament is hidden at accessibility text sizes so reading and controls retain priority. SF Symbols remain the functional icon set.
