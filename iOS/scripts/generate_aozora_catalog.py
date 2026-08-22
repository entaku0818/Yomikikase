#!/usr/bin/env python3
"""青空文庫の公開CSVから、アプリに同梱する作品カタログ(JSON)を生成する。

使い方:
    python3 iOS/scripts/generate_aozora_catalog.py \
        --csv /path/to/list_person_all_extended_utf8.csv \
        --out iOS/VoiceYourText/Resources/AozoraCatalog.json

CSVは青空文庫が公開している以下のZIPを展開したもの:
    https://www.aozora.gr.jp/index_pages/list_person_all_extended_utf8.zip

収録対象は「作品著作権フラグ = なし」(＝著作権保護期間満了) の作品のみ。
掲載作品を入れ替えるときは CURATED を編集して再生成する。
"""
import argparse
import csv
import json
import re
import sys

# (姓, 名, 作品名) の順に並べた掲載順。初回体験用に短編を上へ。
CURATED = [
    ("芥川", "竜之介", "蜘蛛の糸"),
    ("芥川", "竜之介", "羅生門"),
    ("太宰", "治", "走れメロス"),
    ("中島", "敦", "山月記"),
    ("新美", "南吉", "ごん狐"),
    ("梶井", "基次郎", "檸檬"),
    ("宮沢", "賢治", "注文の多い料理店"),
    ("宮沢", "賢治", "よだかの星"),
    ("宮沢", "賢治", "セロ弾きのゴーシュ"),
    ("森", "鴎外", "高瀬舟"),
    ("有島", "武郎", "一房の葡萄"),
    ("新美", "南吉", "手袋を買いに"),
    ("小川", "未明", "赤い蝋燭と人魚"),
    ("芥川", "竜之介", "鼻"),
    ("芥川", "竜之介", "杜子春"),
    ("梶井", "基次郎", "桜の樹の下には"),
    ("夏目", "漱石", "夢十夜"),
    ("坂口", "安吾", "桜の森の満開の下"),
    ("坂口", "安吾", "堕落論"),
    ("太宰", "治", "富嶽百景"),
    ("太宰", "治", "女生徒"),
    ("江戸川", "乱歩", "二銭銅貨"),
    ("江戸川", "乱歩", "人間椅子"),
    ("江戸川", "乱歩", "押絵と旅する男"),
    ("芥川", "竜之介", "地獄変"),
    ("森", "鴎外", "舞姫"),
    ("樋口", "一葉", "たけくらべ"),
    ("樋口", "一葉", "にごりえ"),
    ("堀", "辰雄", "風立ちぬ"),
    ("国木田", "独歩", "武蔵野"),
    ("石川", "啄木", "一握の砂"),
    ("宮沢", "賢治", "風の又三郎"),
    ("宮沢", "賢治", "銀河鉄道の夜"),
    ("夏目", "漱石", "坊っちゃん"),
    ("太宰", "治", "斜陽"),
    ("太宰", "治", "人間失格"),
    ("夏目", "漱石", "こころ"),
    ("夏目", "漱石", "三四郎"),
    ("中島", "敦", "名人伝"),
    ("夏目", "漱石", "吾輩は猫である"),
]

CATALOG_SOURCE = "https://www.aozora.gr.jp/index_pages/list_person_all_extended_utf8.zip"


def card_url(row):
    """CSVの図書カードURLを https に正規化して返す。"""
    url = row["図書カードURL"].strip()
    return re.sub(r"^http://", "https://", url)


def text_zip_url(row):
    return re.sub(r"^http://", "https://", row["テキストファイルURL"].strip())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    with open(args.csv, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    index = {}
    for row in rows:
        if row["役割フラグ"] != "著者":
            continue
        index.setdefault((row["姓"], row["名"], row["作品名"]), row)

    works = []
    missing = []
    for key in CURATED:
        row = index.get(key)
        if row is None:
            missing.append(key)
            continue
        if row["作品著作権フラグ"] != "なし":
            missing.append(key + ("著作権あり",))
            continue
        if not row["テキストファイルURL"].strip():
            missing.append(key + ("テキストなし",))
            continue
        works.append({
            "id": row["作品ID"],
            "title": row["作品名"],
            "subtitle": row["副題"].strip(),
            "author": f'{row["姓"]}{row["名"]}',
            "authorId": row["人物ID"],
            "cardURL": card_url(row),
            "textZipURL": text_zip_url(row),
            "encoding": row["テキストファイル符号化方式"],
        })

    if missing:
        print("見つからなかった作品:", missing, file=sys.stderr)
        return 1

    catalog = {
        "version": 1,
        "source": CATALOG_SOURCE,
        "works": works,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{len(works)}作品を {args.out} に書き出しました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
