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
        ("dictionary", "読み間違いは、\n辞書で直せる", "人名や専門用語の読み方を登録"),
    ],
    "en-US": [
        ("playing", "Listen while\nyou do anything", "Every word highlighted as it's read aloud"),
        ("home", "PDFs, books, web\npages — read aloud", "Text, PDF, ePub, links and scans"),
        ("speed", "Listen at\nyour own pace", "Playback from 0.7x to 2x"),
        ("sleeptimer", "Fall asleep\nlistening", "Sleep timer that fades out gently"),
        ("dictionary", "Fix any\npronunciation", "Teach it names and terms in your dictionary"),
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


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SEEDER = os.path.join(SCRIPT_DIR, "..", "VoiceYourText", "Features", "Debug", "ScreenshotDemoSeeder.swift")
# 1枚目で読み上げているデモ文書のタイトル（本文は ScreenshotDemoSeeder.swift から読む）
PLAYING_TITLE = {"ja": "吾輩は猫である", "en-US": "Alice's Adventures in Wonderland"}
JA_REGULAR = os.path.join(FONT_DIR, "ヒラギノ角ゴシック W4.ttc")
# 拡大して見せる部分（実画面 1320x2868 の座標）。スリープタイマーはミニプレイヤーの帯（残り時間つき）
ZOOM = {"sleeptimer": (20, 2384, 1300, 2616)}


def highlight_box(screen):
    """読み上げ中のハイライト（黄色）の範囲を実画面の座標 (x0, y0, x1, y1) で返す。無ければ None"""
    small = screen.convert("RGB").resize((screen.width // 2, screen.height // 2))
    px = small.load()
    hits = [(x, y) for y in range(small.height) for x in range(small.width)
            if px[x, y][0] > 230 and 150 < px[x, y][1] < 225 and px[x, y][2] < 90]
    if len(hits) < 20:
        return None
    xs, ys = zip(*hits)
    return min(xs) * 2, min(ys) * 2, (max(xs) + 1) * 2, (max(ys) + 1) * 2


def demo_text(lang):
    """シーダーから1枚目のデモ本文を取り出す（Swift の文字列リテラルを連結して戻す）"""
    import re
    src = open(SEEDER, encoding="utf-8").read()
    title = re.escape(PLAYING_TITLE[lang])
    m = re.search(r'title: "' + title + r'",\s*text: (\[.*?\]\.joined\(\)|"(?:[^"\\]|\\.)*")', src, re.S)
    if not m:
        return None
    lits = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))
    return "".join(lits).replace('\\"', '"').replace("\\n", "\n")


def ocr_line(path, line_box, hx0, hx1, lang):
    """1行を読み、(行の文字列, ハイライトにかかる文字列) を返す"""
    import subprocess
    x0, y0, x1, y1 = line_box
    out = subprocess.run(
        ["xcrun", "swift", os.path.join(SCRIPT_DIR, "ocr_region.swift"), path,
         str(x0), str(y0), str(x1 - x0), str(y1 - y0), str(hx0), str(hx1), "ja" if lang == "ja" else "en"],
        capture_output=True, text=True)
    rows = out.stdout.split("\n")
    return (rows[0].strip(), rows[1].strip()) if len(rows) >= 2 else ("", "")


def locate(text, needle, lo=0, hi=None):
    """text[lo:hi] の中で needle に一番似ている窓の開始位置。似ていなければ -1（OCR の読み違い対策）"""
    import difflib
    hi = len(text) if hi is None else hi
    n = len(needle)
    exact = text.find(needle, lo, hi)
    if exact >= 0:
        return exact
    best = max(((difflib.SequenceMatcher(None, needle, text[i:i + n]).ratio(), i)
                for i in range(lo, max(lo, hi - n) + 1)), default=(0, -1))
    return best[1] if best[0] >= 0.7 else -1


def excerpt(text, pos, end, lang, limit=150):
    """pos〜end を含む文を返す。長すぎる文は節（；：、，）の区切りで切り、途中なら … を付ける"""
    import re
    levels = ([r"。|\n", r"、"] if lang == "ja"
              else [r'[.!?]["”]?(?=\s)|\n', r"[;:]", r",(?=\s)"])
    lo, hi = 0, len(text)
    for level, pattern in enumerate(levels):
        cuts = [m.end() for m in re.finditer(pattern, text[lo:hi])]
        begin = max([lo + c for c in cuts if lo + c <= pos], default=lo)
        finish = min([lo + c for c in cuts if lo + c >= end], default=hi)
        lo, hi = begin, finish
        if hi - lo <= limit:
            break
    raw = text[lo:hi]
    lead = len(raw) - len(raw.lstrip())
    sentence = raw.strip().rstrip(",;:、")
    start = pos - lo - lead
    def at_sentence_end(prefix):
        stripped = prefix.rstrip(" ")
        return not stripped.strip() or stripped[-1] in "。.!?\"”\n"
    is_head = at_sentence_end(text[:lo])
    is_tail = at_sentence_end(text[:hi])
    if not is_head:
        sentence, start = "…" + sentence, start + 1
    if not is_tail:
        sentence += "…"
    return sentence, start, start + (end - pos)


def render_callout(sentence, start, end, lang, width):
    """文を折り返して描いたカード。読み上げ中の語に黄色のハイライトを敷く"""
    size = 56
    font = ImageFont.truetype(JA_REGULAR, size) if lang == "ja" else load_font(lang, size, False)
    if lang != "ja":
        try:
            font.set_variation_by_name("Regular")
        except (OSError, ValueError):
            pass
    pad_x, pad_y, line_h = 48, 40, round(size * 1.5)
    max_w = width - pad_x * 2
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    # 折り返しの単位: 日本語は1文字、英語は単語（後ろの空白込み）
    import re
    units = list(sentence) if lang == "ja" else re.findall(r"\S+\s*", sentence)
    # ハイライト中の語は途中で折り返さず、1つの塊として扱う
    merged, i = [], 0
    for u in units:
        if merged and i < end and i + len(u) > start and merged[-1][1] < end and merged[-1][1] + len(merged[-1][0]) > start:
            merged[-1] = (merged[-1][0] + u, merged[-1][1])
        else:
            merged.append((u, i))
        i += len(u)
    units = [u for u, _ in merged]

    def wrap(limit):
        rows, cur, idx = [], [], 0
        for u in units:
            if cur and probe.textlength("".join(t for t, _ in cur) + u.rstrip(), font=font) > limit:
                rows.append(cur)
                cur = []
            cur.append((u, idx))
            idx += len(u)
        if cur:
            rows.append(cur)
        return rows

    # 行数は変えずに、一番狭く収まる幅で折り返し直して行の長さを揃える（最後の行だけ短くならないように）
    lines = wrap(max_w)
    limit = max_w
    while limit > max_w * 0.5 and len(wrap(limit - 10)) == len(lines):
        limit -= 10
    lines = wrap(limit)
    text_w = max(probe.textlength("".join(t for t, _ in line).rstrip(), font=font) for line in lines)
    card = Image.new("RGBA", (round(text_w) + pad_x * 2, pad_y * 2 + line_h * len(lines)), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([0, 0, card.width - 1, card.height - 1], radius=40, fill=(255, 255, 255, 255))
    for row, line in enumerate(lines):
        y = pad_y + row * line_h
        x = pad_x
        for u, i in line:
            text_u = u
            # ハイライト（語の部分だけ。英語は後ろの空白・句読点を含めない）
            hs, he = max(start, i), min(end, i + len(u))
            if hs < he:
                hx0 = x + probe.textlength(u[:hs - i], font=font)
                hx1 = x + probe.textlength(u[:he - i], font=font)
                d.rounded_rectangle([hx0 - 4, y + 6, hx1 + 4, y + line_h - 6], radius=8, fill=(255, 204, 0, 255))
            d.text((x, y + line_h / 2), text_u.rstrip() if lang != "ja" else text_u, font=font,
                   fill=(28, 28, 30, 255), anchor="lm")
            x += probe.textlength(u, font=font)
    return card


def callout(screen_path, screen, lang, width):
    """1枚目の拡大カード。ハイライト中の語を OCR で読み、デモ本文から文の区切りまでを描く。
    読めない・本文に無いときは None（嘘の文を出さないため、カード自体を出さない）"""
    box = highlight_box(screen)
    text = demo_text(lang)
    if not box or not text:
        print("  ⚠️ ハイライトか本文が見つからないので拡大カードを省略", file=sys.stderr)
        return None, None
    # 行全体を読んで本文中の位置を決め（同じ語が何度も出てくる対策）、その中で語を探す
    line, word = ocr_line(screen_path, (40, box[1] + 2, screen.width - 40, box[3] - 2), box[0], box[2], lang)
    word = word.strip(" ,.;:!?\"”“、。")
    line_pos = locate(text, line) if len(line) >= 4 else -1
    pos = locate(text, word, max(line_pos, 0), line_pos + len(line) + 2 if line_pos >= 0 else None) if word else -1
    if pos < 0:
        print(f"  ⚠️ OCR「{line}」/「{word}」が本文に見つからないので拡大カードを省略", file=sys.stderr)
        return None, None
    found = excerpt(text, pos, pos + len(word), lang)
    sentence, start, end = found
    print(f"  拡大カード: 「{sentence}」（{sentence[start:end]}）")
    return render_callout(sentence, start, end, lang, width), box


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

    if raw_name in ZOOM:
        scale = (phone.width - round(phone.width * 0.03) * 2) / screen.width
        x0, y0, x1, y1 = ZOOM[raw_name]
        crop = screen.convert("RGB").crop(ZOOM[raw_name])
        width = CANVAS[0] - 110
        crop = crop.resize((width, round(crop.height * width / crop.width)), Image.LANCZOS)
        mask = Image.new("L", crop.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, crop.width - 1, crop.height - 1], radius=48, fill=255)
        center_y = top + round(phone.width * 0.03) + (y0 + y1) / 2 * scale
        y = round(center_y - crop.height / 2) - 60  # 元の位置より少し上に浮かせる
        card_shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        ImageDraw.Draw(card_shadow).rounded_rectangle([55, y + 24, 55 + width, y + crop.height + 24], radius=48,
                                                      fill=(0, 0, 0, 110))
        canvas.paste(Image.new("RGB", CANVAS, (0, 0, 0)), (0, 0), _blur(card_shadow))
        canvas.paste(crop, (55, y), mask)

    if raw_name == "playing":
        screen_path = os.path.join(raw_dir, f"{raw_name}.png")
        card, box = callout(screen_path, screen, lang, CANVAS[0] - 110)
        if card:
            scale = (phone.width - round(phone.width * 0.03) * 2) / screen.width
            center_y = top + round(phone.width * 0.03) + (box[1] + box[3]) / 2 * scale
            y = round(center_y - card.height / 2)
            x = (CANVAS[0] - card.width) // 2
            card_shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            ImageDraw.Draw(card_shadow).rounded_rectangle(
                [x, y + 20, x + card.width, y + card.height + 20], radius=40, fill=(0, 0, 0, 90))
            canvas.paste(Image.new("RGB", CANVAS, (0, 0, 0)), (0, 0), _blur(card_shadow))
            canvas.paste(card, (x, y), card)
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
    # 枚数が減ったときに古い画像が残らないよう、前回の出力を消してから書く
    for old in os.listdir(args.out):
        if old.startswith("APP_IPHONE_") and old.endswith(".png"):
            os.remove(os.path.join(args.out, old))
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
