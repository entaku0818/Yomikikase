#!/usr/bin/env python3
"""Download pinned prototype model files into ignored android/build/kokoro/."""
import hashlib
from pathlib import Path
import subprocess

REVISION = '1939ad2a8e416c0acfeecc08a694d14ef25f2231'
FILES = {
    'onnx/model_quantized.onnx': ('model.onnx', 'fbae9257e1e05ffc727e951ef9b9c98418e6d79f1c9b6b13bd59f5c9028a1478'),
    'voices/jf_alpha.bin': ('voice.bin', '56b479360aad9f367aeb8cef908f9201cf48b4555e488c5f4590c9dfcd978bb6'),
    'tokenizer.json': ('tokenizer.json', None),
}
root = Path(__file__).resolve().parents[1] / 'build' / 'kokoro'
root.mkdir(parents=True, exist_ok=True)
for remote, (name, digest) in FILES.items():
    target = root / name
    if not target.exists():
        temporary = target.with_suffix('.part')
        subprocess.run(['curl', '-fL', '--retry', '2', '-o', str(temporary), f'https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/{REVISION}/{remote}'], check=True)
        if digest and hashlib.sha256(temporary.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f'Checksum mismatch: {remote}')
        temporary.replace(target)
    data = target.read_bytes()
    if digest and hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError(f'Checksum mismatch: {target}')
    if remote == 'tokenizer.json':
        blob = b'blob ' + str(len(data)).encode() + b'\0' + data
        if hashlib.sha1(blob).hexdigest() != '4280f55fc1c32211bc9bb4d55545759a00054ecd':
            raise RuntimeError('Tokenizer checksum mismatch')
    print(name, len(data), hashlib.sha256(data).hexdigest())
