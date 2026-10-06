#!/usr/bin/env python3
"""App Store 用スクリーンショットの合成（背景・キャッチコピー・端末フレーム）。

素材は AppStoreScreenshotTests が撮った実画面（1320x2868）。
appstore_screenshots.sh から呼ばれるが、単体でも動く:

    python3 iOS/scripts/compose_screenshots.py --lang ja \
        --raw iOS/build/appstore_screenshots/raw/ja --out iOS/build/appstore_screenshots/final/ja

出力: APP_IPHONE_69_<n>.png（1320x2868, 6.9インチ）と APP_IPHONE_67_<n>.png（1290x2796, 6.7インチ）。
どちらも RGB（アルファなし。ASC は透過 PNG を受け付けない）。
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

CANVAS = (1320, 2868)
SIZES = {"69": (1320, 2868), "67": (1290, 2796)}

# 色は DesignSystem/tokens.md の primary (#4B47E0) を基準にする
THEMES = {
    # A: ブランドのインディゴ一色＋白文字（推奨）
    "indigo": {"bg": ((75, 71, 224), (52, 48, 170)), "title": (255, 255, 255), "sub": (214, 212, 255)},
    # B: 薄いラベンダー＋濃い文字（現行に近い明るいトーン）
    "light": {"bg": ((240, 239, 255), (222, 220, 252)), "title": (28, 28, 30), "sub": (75, 71, 224)},
    # C: 夜の濃紺（寝る前・落ち着いたトーン）
    "night": {"bg": ((24, 26, 52), (10, 11, 26)), "title": (255, 255, 255), "sub": (160, 157, 255)},
}

# 各枚のキャッチコピーと素材。実装済みの機能だけを載せる
SLIDES = {
    "ja": [
        ("playing", "家事も通勤も、\nながら聴き。", "読んでいる所をハイライトしながら読み上げ"),
        ("home", "PDFも本もWebも、\nすぐ声に。", "テキスト・PDF・本・リンク・スキャン・名作"),
        ("voices", "人気のキャラ音声で\n読み上げ", "VOICEVOX：ずんだもん・四国めたん ほか"),
        ("classics", "名作文学が、\nすぐ聴ける", "青空文庫の作品を選ぶだけ"),
        ("sleeptimer", "寝る前は\nスリープタイマー", "時間がきたら、そっと停止"),
        ("myfiles", "読みたいものを、\nひとつの本棚に", "PDF・テキスト・本をまとめて管理"),
    ],
    "en-US": [
        ("playing", "Listen while\nyou do anything", "Every word highlighted as it's read aloud"),
        ("home", "PDFs, books, web\npages — read aloud", "Text, PDF, ePub, links and scans"),
        ("speed", "Listen at\nyour own pace", "Playback from 0.7x to 2x"),
        ("sleeptimer", "Fall asleep\nlistening", "Sleep timer that fades out gently"),
        ("myfiles", "All your reading\nin one place", "PDFs, notes and books, organized"),
    ],
}

FONT_DIR = "/System/Library/Fonts"
JA_BOLD = os.path.join(FONT_DIR, "ヒラギノ角ゴシック W8.ttc")
JA_MEDIUM = os.path.join(FONT_DIR, "ヒラギノ角ゴシック W6.ttc")
EN_FONT = os.path.join(FONT_DIR, "SFNS.ttf")


def load_font(lang, size, bold):
    if lang == "ja":
        return ImageFont.truetype(JA_BOLD if bold else JA_MEDIUM, size)
    font = ImageFont.truetype(EN_FONT, size)
    try:
        font.set_variation_by_name("Bold" if bold else "Semibold")
    except (OSError, ValueError):
        pass
    return font


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        draw.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def fit_font(draw, lang, text, max_width, size, bold, spacing_ratio):
    """幅に収まるまでフォントを縮める（日本語の見切れ対策）"""
    while size > 40:
        font = load_font(lang, size, bold)
        box = draw.multiline_textbbox((0, 0), text, font=font, spacing=size * spacing_ratio, align="center")
        if box[2] - box[0] <= max_width:
            return font, size
        size -= 4
    return load_font(lang, size, bold), size


def device(screen, width):
    """実画面を端末フレームに入れる。返り値は RGBA（フレームの外は透過）"""
    bezel = round(width * 0.03)
    inner_w = width - bezel * 2
    inner_h = round(screen.height * inner_w / screen.width)
    height = inner_h + bezel * 2
    outer_r = round(width * 0.16)
    inner_r = outer_r - bezel

    frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, width - 1, height - 1], radius=outer_r, fill=(18, 18, 22, 255))
    # 縁のハイライト（金属の縁）
    d.rounded_rectangle([2, 2, width - 3, height - 3], radius=outer_r - 2, outline=(70, 70, 78, 255), width=3)

    shot = screen.convert("RGB").resize((inner_w, inner_h), Image.LANCZOS)
    mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner_w - 1, inner_h - 1], radius=inner_r, fill=255)
    frame.paste(shot, (bezel, bezel), mask)

    # Dynamic Island（シミュレータの画面には描かれないので足す）
    scale = inner_w / 440  # 実画面は 440pt 幅
    iw, ih, top = 126 * scale, 37 * scale, 11 * scale
    cx = width / 2
    d.rounded_rectangle([cx - iw / 2, bezel + top, cx + iw / 2, bezel + top + ih], radius=ih / 2, fill=(0, 0, 0, 255))
    return frame


def highlight_band(screen):
    """読み上げ中のハイライト（黄色）がある行の上下範囲を実画面の座標で返す。無ければ None"""
    small = screen.convert("RGB").resize((screen.width // 4, screen.height // 4))
    px = small.load()
    rows = [y for y in range(small.height)
            if sum(1 for x in range(small.width)
                   if px[x, y][0] > 230 and 150 < px[x, y][1] < 225 and px[x, y][2] < 90) > 3]
    if not rows:
        return None
    return rows[0] * 4, (rows[-1] + 1) * 4


def callout(screen, band, width, theme):
    """ハイライト行を拡大したカード（1枚目で「今読んでいる所が光る」を伝える）"""
    top, bottom = band
    pad = 2
    crop = screen.convert("RGB").crop((30, max(top - pad, 0), screen.width - 30, min(bottom + pad, screen.height)))
    inner_w = width - 48
    crop = crop.resize((inner_w, round(crop.height * inner_w / crop.width)), Image.LANCZOS)
    card = Image.new("RGBA", (width, crop.height + 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([0, 0, card.width - 1, card.height - 1], radius=36, fill=(255, 255, 255, 255),
                        outline=THEMES[theme]["bg"][0] if theme == "light" else None, width=4)
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, crop.width - 1, crop.height - 1], radius=20, fill=255)
    card.paste(crop, (24, 24), mask)
    return card


def compose(lang, raw_name, title, sub, raw_dir, theme):
    colors = THEMES[theme]
    canvas = gradient(CANVAS, *colors["bg"])
    draw = ImageDraw.Draw(canvas)
    margin = 90

    title_font, title_size = fit_font(draw, lang, title, CANVAS[0] - margin * 2, 124 if lang == "ja" else 136, True, 0.22)
    y = 190
    draw.multiline_text((CANVAS[0] / 2, y), title, font=title_font, fill=colors["title"], anchor="ma",
                        align="center", spacing=title_size * 0.22)
    box = draw.multiline_textbbox((CANVAS[0] / 2, y), title, font=title_font, anchor="ma", align="center",
                                  spacing=title_size * 0.22)
    sub_font, _ = fit_font(draw, lang, sub, CANVAS[0] - margin * 2, 52, False, 0)
    draw.text((CANVAS[0] / 2, box[3] + 48), sub, font=sub_font, fill=colors["sub"], anchor="ma")

    screen = Image.open(os.path.join(raw_dir, f"{raw_name}.png"))
    phone = device(screen, 1010)
    # 端末は下端を少しはみ出させて大きく見せる
    top = max(box[3] + 170, 690)
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(CANVAS[0] - phone.width) / 2 + 10, top + 30, (CANVAS[0] + phone.width) / 2 - 10, top + phone.height],
        radius=160, fill=(0, 0, 0, 70))
    canvas.paste(Image.new("RGB", CANVAS, (0, 0, 0)), (0, 0), _blur(shadow))
    phone_x = (CANVAS[0] - phone.width) // 2
    canvas.paste(phone, (phone_x, top), phone)

    if raw_name == "playing":
        band = highlight_band(screen)
        if band:
            card = callout(screen, band, CANVAS[0] - 110, theme)
            scale = (phone.width - round(phone.width * 0.03) * 2) / screen.width
            center_y = top + round(phone.width * 0.03) + (band[0] + band[1]) / 2 * scale
            y = round(center_y - card.height / 2)
            card_shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            ImageDraw.Draw(card_shadow).rounded_rectangle(
                [55, y + 20, 55 + card.width, y + card.height + 20], radius=36, fill=(0, 0, 0, 90))
            canvas.paste(Image.new("RGB", CANVAS, (0, 0, 0)), (0, 0), _blur(card_shadow))
            canvas.paste(card, (55, y), card)
    return canvas


def _blur(rgba):
    from PIL import ImageFilter
    return rgba.split()[3].filter(ImageFilter.GaussianBlur(40))


def compare(lang, old_dir, new_dir, out_path):
    """旧（fastlane/screenshots の 6.7インチ）と新を上下2段に並べた確認用の1枚"""
    import glob
    thumb_w = 400
    def thumbs(paths):
        return [Image.open(f).convert("RGB").resize((thumb_w, round(Image.open(f).height * thumb_w / Image.open(f).width)))
                for f in paths]
    old = thumbs(sorted(glob.glob(os.path.join(old_dir, "*_APP_IPHONE_67_*.png"))))
    new = thumbs([os.path.join(new_dir, f"APP_IPHONE_69_{i}.png") for i in range(len(SLIDES[lang]))])
    gap, label_h = 24, 90
    cols = max(len(old), len(new))
    row_h = max(t.height for t in old + new)
    sheet = Image.new("RGB", (gap + cols * (thumb_w + gap), (label_h + row_h + gap) * 2), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    font = load_font("ja", 48, True)
    for r, (label, row) in enumerate([("旧（現在公開中）", old), ("新（案）", new)]):
        y = r * (label_h + row_h + gap)
        d.text((gap, y + 20), f"{lang}  {label}", font=font, fill=(28, 28, 30))
        for c, t in enumerate(row):
            sheet.paste(t, (gap + c * (thumb_w + gap), y + label_h))
    sheet.save(out_path)
    print(f"  比較: {out_path}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--lang", required=True, choices=sorted(SLIDES))
    p.add_argument("--raw", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--theme", default="indigo", choices=sorted(THEMES))
    p.add_argument("--compare-old", help="旧スクショのディレクトリ。指定すると旧新比較の1枚も出す")
    args = p.parse_args()

    os.makedirs(args.out, exist_ok=True)
    missing = [n for n, _, _ in SLIDES[args.lang] if not os.path.exists(os.path.join(args.raw, f"{n}.png"))]
    if missing:
        sys.exit(f"素材がありません: {', '.join(missing)}（{args.raw}）")

    for i, (name, title, sub) in enumerate(SLIDES[args.lang]):
        img = compose(args.lang, name, title, sub, args.raw, args.theme)
        for key, size in SIZES.items():
            out = img if size == CANVAS else img.resize(size, Image.LANCZOS)
            path = os.path.join(args.out, f"APP_IPHONE_{key}_{i}.png")
            out.convert("RGB").save(path, optimize=True)
        print(f"  {args.lang} {i}: {name}")
    if args.compare_old:
        compare(args.lang, args.compare_old, args.out, os.path.join(args.out, "..", f"compare_{args.lang}.png"))


if __name__ == "__main__":
    main()
