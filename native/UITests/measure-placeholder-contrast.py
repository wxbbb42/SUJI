"""Measure solid placeholder glyphs in the accepted simulator PNGs (requires Pillow).

Run after exporting screenshots. This checks four specific rendered states, not
whole-app WCAG conformance. Antialiased edge shades are excluded from foreground.
"""
from collections import Counter
from hashlib import sha256
from json import dumps
from pathlib import Path

from PIL import Image

native = Path(__file__).resolve().parents[1]
output = native / "Documentation/mingli-details/placeholder-contrast.json"
roi = (90, 2210, 700, 2310)
files = {
    "before-light": "mingli-improvements/10-chat-start.png",
    "after-light": "mingli-details/60-chat-placeholder-light.png",
    "before-dark": "mingli-improvements/24-dark-chat.png",
    "after-dark": "mingli-details/61-chat-placeholder-dark.png",
}


def luminance(rgb):
    def linear(channel):
        value = channel / 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return sum(weight * linear(value) for weight, value in zip((0.2126, 0.7152, 0.0722), rgb))


states = []
for state, relative in files.items():
    file = native / "Documentation" / relative
    image = Image.open(file).convert("RGB")
    assert image.size == (1206, 2622), "Revisit ROI when device or screen dimensions change"
    counts = Counter(image.crop(roi).getdata())
    background = counts.most_common(1)[0][0]
    # The most frequent shade away from the flat background is the solid glyph
    # interior. Reject the near-background surface shades before ranking.
    foreground, count = next((color, count) for color, count in counts.most_common()
                             if sum((a - b) ** 2 for a, b in zip(color, background)) > 25 ** 2)
    assert count > 2000, "Insufficient solid glyph pixels; inspect the new screenshot"
    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    ratio = (light + 0.05) / (dark + 0.05)
    states.append({"state": state, "file": relative, "sha256": sha256(file.read_bytes()).hexdigest(),
                   "foreground": "#%02X%02X%02X" % foreground, "background": "#%02X%02X%02X" % background,
                   "solidGlyphPixels": count, "contrastRatio": round(ratio, 3),
                   "meetsNormalText4_5": ratio >= 4.5})

output.write_text(dumps({"roiPixels": roi, "screenPixels": [1206, 2622],
                         "method": "sRGB relative luminance; modal solid glyph interior versus modal local background",
                         "scope": "Chat placeholder in four captured static states; not a whole-app accessibility certification",
                         "states": states}, ensure_ascii=False, indent=2) + "\n")
print(output)
