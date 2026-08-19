"""Pixel-perfect navy/gold UI chrome ninepatches (ModularCards bevel language)."""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent

# Theme / card palette
BLACK = (0, 0, 0, 255)
NAVY_BG = (15, 18, 26, 242)  # #0F121A
NAVY_FILL = (31, 36, 51, 242)  # #1F2433
NAVY_HOVER = (51, 61, 87, 250)  # #333D57
NAVY_PRESSED = (20, 26, 36, 250)  # #141A24
NAVY_EDGE = (12, 14, 20, 255)
SILVER = (191, 199, 217, 255)  # #BFC7D9
SILVER_DIM = (130, 138, 158, 255)
GOLD = (242, 230, 140, 255)  # #F2E68C
GOLD_DARK = (217, 184, 71, 255)  # #D9B847
GOLD_BRONZE = (184, 148, 71, 255)  # #B89447
SAPPHIRE = (51, 136, 222, 255)  # #3388DE
SAPPHIRE_DARK = (26, 74, 140, 255)  # #1a4a8c
CHIP_FILL = (18, 22, 32, 250)
GOLD_FILL = (36, 28, 18, 248)
DISABLED_FILL = (28, 30, 36, 220)
DISABLED_RIM = (110, 114, 124, 255)


def px(img: Image.Image, x: int, y: int, color: tuple) -> None:
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), color)


def fill_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, color)


def hline(img: Image.Image, x0: int, x1: int, y: int, color: tuple) -> None:
    for x in range(x0, x1 + 1):
        px(img, x, y, color)


def vline(img: Image.Image, x: int, y0: int, y1: int, color: tuple) -> None:
    for y in range(y0, y1 + 1):
        px(img, x, y, color)


def round_cut(img: Image.Image, inset: int = 0) -> None:
    """Cut outer corner pixel for ModularCards-style rounded square."""
    w, h = img.size
    transparent = (0, 0, 0, 0)
    corners = (
        (inset, inset),
        (w - 1 - inset, inset),
        (inset, h - 1 - inset),
        (w - 1 - inset, h - 1 - inset),
    )
    for x, y in corners:
        px(img, x, y, transparent)


def draw_beveled_frame(
    size: tuple[int, int],
    fill: tuple,
    rim: tuple,
    gem: tuple,
    invert_bevel: bool = False,
    gold_inner: bool = True,
) -> Image.Image:
    """Concentric chrome: black > bevel > gold > sapphire > navy body > fill.

    Outer 8px is the nine-slice margin; center is uniform fill.
    """
    w, h = size
    img = Image.new("RGBA", (w, h), fill)
    hi = SILVER if not invert_bevel else NAVY_EDGE
    lo = NAVY_EDGE if not invert_bevel else SILVER_DIM

    # 0 black outline
    hline(img, 1, w - 2, 0, BLACK)
    hline(img, 1, w - 2, h - 1, BLACK)
    vline(img, 0, 1, h - 2, BLACK)
    vline(img, w - 1, 1, h - 2, BLACK)

    # 1 bevel
    hline(img, 2, w - 3, 1, hi)
    vline(img, 1, 2, h - 3, hi)
    hline(img, 2, w - 3, h - 2, lo)
    vline(img, w - 2, 2, h - 3, lo)
    px(img, 1, 1, hi)
    px(img, w - 2, 1, lo)
    px(img, 1, h - 2, lo)
    px(img, w - 2, h - 2, lo)

    # 2 gold / bronze rim
    rim_lo = GOLD_BRONZE if gold_inner else SILVER_DIM
    hline(img, 3, w - 4, 2, rim)
    vline(img, 2, 3, h - 4, rim)
    hline(img, 3, w - 4, h - 3, rim_lo)
    vline(img, w - 3, 3, h - 4, rim_lo)

    # 3 sapphire class line
    hline(img, 4, w - 5, 3, gem)
    vline(img, 3, 4, h - 5, gem)
    hline(img, 4, w - 5, h - 4, SAPPHIRE_DARK)
    vline(img, w - 4, 4, h - 5, SAPPHIRE_DARK)

    # 4 inner navy body (keeps slice margin solid)
    hline(img, 5, w - 6, 4, NAVY_FILL)
    vline(img, 4, 5, h - 6, NAVY_FILL)
    hline(img, 5, w - 6, h - 5, NAVY_BG)
    vline(img, w - 5, 5, h - 6, NAVY_BG)

    # 5 inner shadow so text does not sit on gem
    hline(img, 6, w - 7, 5, NAVY_BG)
    vline(img, 5, 6, h - 7, NAVY_BG)
    hline(img, 6, w - 7, h - 6, NAVY_FILL)
    vline(img, w - 6, 6, h - 7, NAVY_FILL)

    round_cut(img, 0)
    return img


def save(name: str, img: Image.Image) -> None:
    path = OUT / name
    img.save(path, "PNG")
    print(f"wrote {path.name} {img.size}")


def main() -> None:
    panel = draw_beveled_frame((48, 48), NAVY_BG, GOLD_DARK, SAPPHIRE)
    save("panel.png", panel)

    hud = draw_beveled_frame((96, 32), NAVY_BG, GOLD_DARK, SAPPHIRE)
    save("hud_bar.png", hud)

    chip = draw_beveled_frame((32, 32), CHIP_FILL, GOLD, SAPPHIRE)
    save("chip.png", chip)

    gold_panel = draw_beveled_frame((48, 48), GOLD_FILL, GOLD, GOLD_DARK)
    save("panel_gold.png", gold_panel)

    btn = draw_beveled_frame((48, 32), NAVY_FILL, SILVER, SAPPHIRE_DARK)
    save("button_normal.png", btn)

    btn_h = draw_beveled_frame((48, 32), NAVY_HOVER, GOLD, SAPPHIRE)
    save("button_hover.png", btn_h)

    btn_p = draw_beveled_frame((48, 32), NAVY_PRESSED, GOLD_BRONZE, SAPPHIRE_DARK, invert_bevel=True)
    save("button_pressed.png", btn_p)

    btn_d = draw_beveled_frame((48, 32), DISABLED_FILL, DISABLED_RIM, SILVER_DIM, gold_inner=False)
    save("button_disabled.png", btn_d)


if __name__ == "__main__":
    main()
