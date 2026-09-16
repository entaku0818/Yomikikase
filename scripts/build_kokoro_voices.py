#!/usr/bin/env python3
"""LP/public/kokoro/voices-v1.npz を再生成する。

背景:
  アプリはもともと第三者リポジトリ mlalma/KokoroTestApp の voices.npz を
  media.githubusercontent.com（GitHub LFS 用 CDN）から取得していたが、

    1. 同ファイルが LFS 管理から外れたため、その URL は 404 を返すようになった
    2. そもそも中身は英語28音声のみで、日本語 (jf_* / jm_*) が1つも入っていない
       → アプリが公開している jf_alpha / jm_kumo は実行時に必ず見つからず、
         端末TTSへサイレントフォールバックしていた

  そこで、英語28音声（従来と同一バイト）に公式 Kokoro-82M の日本語5音声を
  足した npz を自前で生成し、Firebase Hosting (voiceyourtext.web.app) から配る。

出力:
  LP/public/kokoro/voices-v1.npz  (33音声 / ZIP_STORED / 約17MB)
  ※ ファイル名にバージョンを含める。中身を変える時は v2 を作り、古い
     クライアントが参照する v1 は消さないこと。

必要なもの:
  python3 -m venv .venv && ./.venv/bin/pip install torch numpy

使い方:
  ./.venv/bin/python scripts/build_kokoro_voices.py
"""
import io
import os
import sys
import urllib.request
import zipfile

import numpy as np
import torch

ENGLISH_NPZ_URL = "https://raw.githubusercontent.com/mlalma/KokoroTestApp/main/Resources/voices.npz"
JA_VOICE_URL = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/voices/{name}.pt"
JA_VOICES = ["jf_alpha", "jf_gongitsune", "jf_nezumi", "jf_tebukuro", "jm_kumo"]

# Kokoro-82M のボイス埋め込みの形状。全音声で共通で、これ以外は受け付けない。
EXPECTED_SHAPE = (510, 1, 256)
EXPECTED_DTYPE = np.dtype("<f4")

OUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "LP", "public", "kokoro", "voices-v1.npz",
)


def fetch(url: str) -> bytes:
    print(f"  fetching {url}")
    with urllib.request.urlopen(url, timeout=180) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status} for {url}")
        return resp.read()


def main() -> int:
    print("1) 英語28音声の npz を取得")
    english = zipfile.ZipFile(io.BytesIO(fetch(ENGLISH_NPZ_URL)))
    english_names = sorted(n for n in english.namelist() if n.endswith(".npy"))
    print(f"   {len(english_names)} voices")

    print("2) 日本語5音声を HuggingFace から取得して .pt → .npy 変換")
    japanese: dict[str, bytes] = {}
    for name in JA_VOICES:
        raw = fetch(JA_VOICE_URL.format(name=name))
        tensor = torch.load(io.BytesIO(raw), map_location="cpu", weights_only=True)
        array = tensor.numpy().astype("<f4")
        if array.shape != EXPECTED_SHAPE or array.dtype != EXPECTED_DTYPE:
            raise RuntimeError(f"{name}: unexpected {array.shape} {array.dtype}")
        buf = io.BytesIO()
        np.save(buf, array, allow_pickle=False)
        japanese[f"{name}.npy"] = buf.getvalue()

    print("3) マージして書き出し")
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    # 圧縮しない (ZIP_STORED)。元の npz と同じ形式で、iOS 側 ZIPFoundation の
    # 読み出しが最も素直に通る。埋め込みは float32 の密行列で圧縮も効かない。
    with zipfile.ZipFile(OUT_PATH, "w", zipfile.ZIP_STORED) as out:
        for name in english_names:
            out.writestr(name, english.read(name))
        for name, data in japanese.items():
            out.writestr(name, data)

    print("4) 検証")
    check = zipfile.ZipFile(OUT_PATH)
    keys = sorted(n[:-4] for n in check.namelist() if n.endswith(".npy"))
    for key in keys:
        array = np.load(io.BytesIO(check.read(f"{key}.npy")))
        if array.shape != EXPECTED_SHAPE or array.dtype != EXPECTED_DTYPE:
            raise RuntimeError(f"{key}: unexpected {array.shape} {array.dtype}")
        if not np.isfinite(array).all():
            raise RuntimeError(f"{key}: contains NaN/Inf")
    missing = [v for v in JA_VOICES if v not in keys]
    if missing:
        raise RuntimeError(f"日本語音声が欠けている: {missing}")
    with open(OUT_PATH, "rb") as handle:
        if handle.read(4) != b"PK\x03\x04":
            raise RuntimeError("ZIP マジックバイトが不正")

    print(f"   OK: {len(keys)} voices, {os.path.getsize(OUT_PATH) / 1e6:.1f} MB")
    print(f"   -> {OUT_PATH}")
    print("\n次: cd LP && firebase deploy --only hosting")
    return 0


if __name__ == "__main__":
    sys.exit(main())
