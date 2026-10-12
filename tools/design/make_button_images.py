"""Draws the stone-green UI button backgrounds (cut corners, double bevel, gradient, diamond ornaments) as PNGs.

Run:  python tools/design/make_button_images.py     (needs Pillow)
Output: design/buttons/Btn_<State>.png, 512 x 160, transparent background, no text.

The images are sliced 9-patch style in Roblox (see Theme.stoneButton): the corners hold the cut corner, the bevel and
the diamonds and must stay fixed, the middle stretches. Keep SLICE in sync with Theme.lua.
Neutral = a grey version that the game tints with ImageColor3 for the other button colours (red, gold, blue ...).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 512, 160  # final image size (the button shape inside has a 16 px margin so the glow fits)
S = 4  # supersampling for smooth edges
M = 16  # margin
CUT = 26  # corner cut
LIP = 6  # thickness of the dark lip under the button
SLICE = (80, 56, 432, 104)  # left, top, right, bottom of the stretchable middle (image px)

STATES = {
    "Default": dict(border=((122, 196, 156), (58, 118, 90)), fill=((92, 150, 120), (26, 50, 38)), inner=(150, 236, 186), diamond=(96, 224, 154), lip=(20, 44, 34), glow=None),
    "Hover": dict(border=((158, 236, 188), (78, 170, 120)), fill=((136, 206, 164), (38, 84, 60)), inner=(204, 255, 222), diamond=(150, 255, 196), lip=(24, 60, 44), glow=(110, 255, 170)),
    "Pressed": dict(border=((64, 116, 90), (34, 68, 52)), fill=((48, 88, 66), (20, 38, 30)), inner=(104, 196, 144), diamond=(80, 180, 126), lip=(14, 28, 22), glow=None),
    "Disabled": dict(border=((100, 110, 104), (60, 68, 64)), fill=((84, 94, 88), (34, 40, 38)), inner=(116, 126, 120), diamond=(88, 102, 94), lip=(22, 26, 24), glow=None),
    # the grey master that the game tints (multiply) for other colours: bright, with the same bevel and gradient shapes
    "Neutral": dict(border=((236, 236, 236), (150, 150, 150)), fill=((214, 214, 214), (92, 92, 92)), inner=(255, 255, 255), diamond=(255, 255, 255), lip=(70, 70, 70), glow=None),
}


def octagon(inset, cut, dy=0):
    x0, y0, x1, y1 = (M + inset) * S, (M + inset + dy) * S, (W - M - inset) * S, (H - M - inset + dy) * S
    c = cut * S
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def vertical_gradient(top, bottom, split=0.5, soft=0.12):
    """A gradient with a lighter top half and a darker bottom half, blended around the middle (like the Figma design)."""
    img = Image.new("RGB", (W * S, H * S))
    px = img.load()
    for y in range(H * S):
        t = y / (H * S - 1)
        k = min(1.0, max(0.0, (t - (split - soft)) / (2 * soft)))
        k = k * k * (3 - 2 * k)
        a = tuple(int(top[i] * (1 - 0.18 * t) ) for i in range(3))  # slight fade inside the top half
        b = tuple(int(bottom[i] * (1 + 0.1 * (1 - t))) for i in range(3))
        col = tuple(min(255, int(a[i] * (1 - k) + b[i] * k)) for i in range(3))
        for x in range(W * S):
            px[x, y] = col
    return img


def polygon_mask(points):
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def diamond(draw, cx, cy, r, color):
    draw.polygon([(cx, cy - r), (cx + r * 0.62, cy), (cx, cy + r), (cx - r * 0.62, cy)], fill=color)


def make(name, st):
    canvas = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))

    # glow (hover): a blurred copy of the outline behind everything
    if st["glow"]:
        glow = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
        ImageDraw.Draw(glow).polygon(octagon(-4, CUT + 4), fill=st["glow"] + (210,))
        glow = glow.filter(ImageFilter.GaussianBlur(10 * S))
        canvas = Image.alpha_composite(canvas, glow)

    # dark lip under the button
    lip = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    ImageDraw.Draw(lip).polygon(octagon(0, CUT, LIP), fill=st["lip"] + (255,))
    canvas = Image.alpha_composite(canvas, lip)

    # outer bevel: vertical gradient clipped to the cut-corner shape
    outer = vertical_gradient(st["border"][0], st["border"][1], split=0.5, soft=0.45).convert("RGBA")
    outer.putalpha(polygon_mask(octagon(0, CUT)))
    canvas = Image.alpha_composite(canvas, outer)

    # fill: lighter top half, darker bottom half
    fill = vertical_gradient(st["fill"][0], st["fill"][1], split=0.5, soft=0.1).convert("RGBA")
    fill.putalpha(polygon_mask(octagon(9, CUT - 7)))
    canvas = Image.alpha_composite(canvas, fill)

    # thin bright inner line
    d = ImageDraw.Draw(canvas)
    ring = octagon(15, CUT - 12)
    d.line(ring + [ring[0]], fill=st["inner"] + (255,), width=3 * S, joint="curve")

    # diamond ornaments (inside the fixed corner pieces so they never stretch)
    cy = H * S // 2
    r = 11 * S
    diamond(d, (M + 36) * S, cy, r, st["diamond"] + (255,))
    diamond(d, (W - M - 36) * S, cy, r, st["diamond"] + (255,))

    return canvas.resize((W, H), Image.LANCZOS)


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "..", "design", "buttons")
    os.makedirs(out, exist_ok=True)
    for name, st in STATES.items():
        path = os.path.join(out, "Btn_" + name + ".png")
        make(name, st).save(path)
        print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
