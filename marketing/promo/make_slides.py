"""Generates the Teman Kereta promo carousel (3:4 slides), reusing the
app's real palette/type from app_theme.dart + PRD.md, the real app icon,
and real on-device screenshots captured earlier this session."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/run/media/xyyxzxx/8ED6D8FAD6D8E40D/Projet/Teman Kereta")
SCRATCH = Path(
    "/tmp/claude-1000/-run-media-xyyxzxx-8ED6D8FAD6D8E40D-Projet-Teman-Kereta"
    "/792dad71-f67e-4bba-acec-df2ddac63d38/scratchpad"
)
OUT = SCRATCH / "promo"

# --- Real app palette (lib/app/theme/app_theme.dart) ---------------------
NAVY = (16, 42, 67)
CORAL = (255, 90, 95)
BG_LIGHT = (247, 249, 252)
TEXT_SECONDARY = (82, 103, 125)

W, H = 1200, 1600  # 3:4

FONT_PATH = str(ROOT / "assets/fonts/PlusJakartaSans-Variable.ttf")
ICON_PATH = str(ROOT / "assets/branding/tk_icon.png")

_FONT_CACHE = {}


def font(size, weight="Regular"):
    key = (size, weight)
    if key not in _FONT_CACHE:
        f = ImageFont.truetype(FONT_PATH, size)
        f.set_variation_by_name(weight)
        _FONT_CACHE[key] = f
    return _FONT_CACHE[key]


def draw_dot_grid(spacing=40, radius=1.6, alpha=26):
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    color = (*NAVY, alpha)
    for y in range(spacing, H, spacing):
        for x in range(spacing, W, spacing):
            od.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    return overlay


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def wordmark_row(draw, img, cx, top, icon_size=76, gap=18, wm_size=58):
    icon = Image.open(ICON_PATH).convert("RGBA").resize((icon_size, icon_size), Image.LANCZOS)
    wm_font = font(wm_size, "ExtraBold")
    text = "Teman Kereta"
    bbox = draw.textbbox((0, 0), text, font=wm_font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    total_w = icon_size + gap + text_w + 22
    x = cx - total_w // 2
    img.paste(icon, (x, top), icon)
    text_y = top + (icon_size - text_h) // 2 - bbox[1]
    draw.text((x + icon_size + gap, text_y), text, font=wm_font, fill=NAVY)
    dot_cx = x + icon_size + gap + text_w + 10
    dot_cy = top + 6
    draw.ellipse((dot_cx - 6, dot_cy - 6, dot_cx + 6, dot_cy + 6), fill=CORAL)
    return top + icon_size


def centered_text(draw, text, cy, f, fill):
    bbox = draw.textbbox((0, 0), text, font=f)
    w = bbox[2] - bbox[0]
    x = (W - w) // 2 - bbox[0]
    draw.text((x, cy), text, font=f, fill=fill)


def draw_rich_paragraphs(draw, paragraphs, x, top, max_width, line_gap=16, para_gap=24):
    """paragraphs: list of paragraphs; each paragraph is a list of (text, font,
    color) runs, concatenated with no implied space between runs (so a run
    boundary can fall mid-word, e.g. a bold word followed by a
    regular-weight trailing comma with no gap). Splitting happens on the
    space characters actually present in each run's own text."""
    cy = top
    for paragraph in paragraphs:
        words = []  # each word: list of (text_fragment, font, color) sub-runs
        current = []
        for text, f, color in paragraph:
            parts = text.split(" ")
            for i, part in enumerate(parts):
                if i > 0:
                    if current:
                        words.append(current)
                        current = []
                if part:
                    current.append((part, f, color))
        if current:
            words.append(current)
        if not words:
            continue

        space_w = draw.textlength(" ", font=words[0][0][1])

        def word_width(word):
            return sum(draw.textlength(t, font=f) for t, f, _ in word)

        def word_height(word):
            return max(f.getbbox("Ag")[3] - f.getbbox("Ag")[1] for _, f, _ in word)

        line_words = []
        line_width = 0
        max_line_h = 0

        def flush():
            nonlocal cy, line_words, line_width, max_line_h
            cx = x
            for word in line_words:
                for t, f, c in word:
                    draw.text((cx, cy), t, font=f, fill=c)
                    cx += draw.textlength(t, font=f)
                cx += space_w
            cy += max_line_h + line_gap
            line_words = []
            line_width = 0
            max_line_h = 0

        for word in words:
            ww = word_width(word)
            wh = word_height(word)
            extra = space_w if line_words else 0
            if line_width + extra + ww > max_width and line_words:
                flush()
                line_words = [word]
                line_width = ww
                max_line_h = wh
            else:
                line_words.append(word)
                line_width += extra + ww
                max_line_h = max(max_line_h, wh)
        if line_words:
            flush()
        cy += para_gap
    return cy


def phone_mockup(base, screenshot_path, x, top, phone_w, crop_top=0, peek_height=None):
    """Draws a phone frame at (x, top) sized to fit the screenshot's own
    aspect ratio exactly (no horizontal crop, ever), then top-crops to
    peek_height for a deliberate "hero peek" (or shows the full screenshot
    when peek_height is None). Returns the outer phone height actually used,
    so callers can position whatever comes after it."""
    border_w = int(phone_w * 0.028)
    inset = border_w + 2
    target_w = phone_w - inset * 2

    screen = Image.open(screenshot_path).convert("RGB")
    sw, sh = screen.size
    if crop_top:
        screen = screen.crop((0, crop_top, sw, sh))
        sw, sh = screen.size
    scale = target_w / sw
    rh = round(sh * scale)
    screen = screen.resize((target_w, rh), Image.LANCZOS)
    target_h = min(peek_height, rh) if peek_height else rh
    screen = screen.crop((0, 0, target_w, target_h))

    phone_h = target_h + inset * 2
    bezel_radius = int(phone_w * 0.11)
    bezel = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bezel)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (x + 14, top + 26, x + phone_w + 14, top + phone_h + 26), radius=bezel_radius,
        fill=(*NAVY, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    base.alpha_composite(shadow)

    bd.rounded_rectangle((0, 0, phone_w - 1, phone_h - 1), radius=bezel_radius, fill=(9, 13, 20, 255))
    bd.rounded_rectangle(
        (border_w, border_w, phone_w - border_w, phone_h - border_w),
        radius=int(bezel_radius * 0.72),
        fill=(255, 255, 255, 255),
    )

    screen_mask = rounded_mask((target_w, target_h), int(bezel_radius * 0.62))
    bezel.paste(screen, (inset, inset), screen_mask)

    cx = phone_w // 2
    bd.ellipse((cx - 9, border_w + 14, cx + 9, border_w + 32), fill=(30, 34, 40, 255))
    bd.rounded_rectangle((-4, int(phone_h * 0.16), 4, int(phone_h * 0.16) + 70), radius=4, fill=(9, 13, 20, 255))
    bd.rounded_rectangle((-4, int(phone_h * 0.26), 4, int(phone_h * 0.26) + 100), radius=4, fill=(9, 13, 20, 255))
    bd.rounded_rectangle((phone_w - 4, int(phone_h * 0.20), phone_w + 4, int(phone_h * 0.20) + 110), radius=4, fill=(9, 13, 20, 255))

    base.alpha_composite(bezel, (x, top))
    return phone_h


def base_canvas():
    img = Image.new("RGBA", (W, H), (*BG_LIGHT, 255))
    img.alpha_composite(draw_dot_grid())
    draw = ImageDraw.Draw(img)
    return img, draw


def footer_watermark(img, draw):
    icon = Image.open(ICON_PATH).convert("RGBA").resize((36, 36), Image.LANCZOS)
    x, y = 56, H - 84
    img.paste(icon, (x, y), icon)
    f = font(26, "Bold")
    draw.text((x + 46, y + 4), "Teman Kereta", font=f, fill=NAVY)
    bbox = draw.textbbox((x + 46, y + 4), "Teman Kereta", font=f)
    draw.ellipse((bbox[2] + 8, y + 6, bbox[2] + 20, y + 18), fill=CORAL)


def slide_cover():
    img, draw = base_canvas()
    centered_text(draw, "Introducing", 96, font(34, "Medium"), TEXT_SECONDARY)
    wordmark_row(draw, img, W // 2, 150)
    tag_f = font(32, "Medium")
    centered_text(draw, "Selalu tau posisi keretamu,", 268, tag_f, TEXT_SECONDARY)
    centered_text(draw, "sebelum kelewat stasiun.", 312, tag_f, TEXT_SECONDARY)

    phone_w = 680
    phone_mockup(
        img,
        str(SCRATCH / "12_active_trip.png"),
        W // 2 - phone_w // 2, 400, phone_w,
        peek_height=980,
    )
    footer_watermark(img, draw)
    img.convert("RGB").save(OUT / "slide_1_cover.png")


def header_block(img, draw, eyebrow, tagline):
    centered_text(draw, eyebrow, 70, font(30, "Medium"), TEXT_SECONDARY)
    wordmark_row(draw, img, W // 2, 116, icon_size=58, wm_size=46)
    centered_text(draw, tagline, 216, font(26, "Medium"), TEXT_SECONDARY)


def slide_what_is():
    img, draw = base_canvas()
    header_block(img, draw, "What is", "Selalu tau posisi keretamu, sebelum kelewat stasiun.")

    body_x, body_top, body_w = 70, 320, 500
    bold = font(30, "Bold")
    reg = font(30, "Regular")
    paragraphs = [
        [
            ("Teman Kereta", bold, NAVY),
            (
                " melacak posisi KRL kamu secara otomatis begitu naik kereta, "
                "tanpa perlu bolak-balik buka aplikasi.",
                reg, NAVY,
            ),
        ],
        [(
            "Mendekati tujuan, notifikasi masuk bertahap: tiga stasiun lagi, "
            "dua stasiun lagi, sampai saatnya bersiap turun. Kalau ternyata "
            "kebablasan, Teman Kereta juga yang pertama kasih tahu.",
            reg, NAVY,
        )],
        [(
            "Semua ini tetap jalan meski HP terkunci atau sinyal sempat "
            "hilang sebentar, jadi kamu bisa dengerin musik atau merem "
            "sejenak tanpa was-was kelewatan stasiun.",
            reg, NAVY,
        )],
    ]
    draw_rich_paragraphs(draw, paragraphs, body_x, body_top, body_w)

    phone_w = 500
    phone_mockup(
        img,
        str(SCRATCH / "11_restart_home.png"),
        W - phone_w - 40, 380, phone_w,
    )
    footer_watermark(img, draw)
    img.convert("RGB").save(OUT / "slide_2_what_is.png")


def slide_scope():
    img, draw = base_canvas()
    header_block(img, draw, "What else", "Bukan cuma soal turun di stasiun yang tepat.")

    body_x, body_top, body_w = 70, 320, 500
    bold = font(30, "Bold")
    reg = font(30, "Regular")
    paragraphs = [
        [
            ("Sebelum naik kereta", bold, NAVY),
            (
                ", Teman Kereta bantu kamu cari jadwal dan rute KRL, termasuk "
                "kalau perjalananmu perlu transit, lengkap dengan perkiraan "
                "waktu tiba.",
                reg, NAVY,
            ),
        ],
        [(
            "Ada juga peta yang menunjukkan posisi kereta secara real-time "
            "di jalurnya, dan forum kecil buat sesama penumpang saling "
            "kabari kondisi perjalanan hari ini.",
            reg, NAVY,
        )],
    ]
    draw_rich_paragraphs(draw, paragraphs, body_x, body_top, body_w)

    phone_w = 500
    phone_mockup(
        img,
        str(SCRATCH / "03_home_scrolled.png"),
        W - phone_w - 40, 380, phone_w,
        crop_top=80,
    )
    footer_watermark(img, draw)
    img.convert("RGB").save(OUT / "slide_3_scope.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    slide_cover()
    slide_what_is()
    slide_scope()
    print("done")
