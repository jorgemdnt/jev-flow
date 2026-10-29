#!/usr/bin/env python3
"""Download the Parakeet files JevFlow runs, not the whole Hub repo.

usage: fetch-parakeet.py <cache-dir> [tdt|ctc]

tdt (default) is the v3 recognizer. ctc is the 110M word spotter that finds
dictionary terms in the audio.
"""

import json
import os
import subprocess
import sys
import urllib.request

MODELS = {
    "tdt": {
        "repo": "FluidInference/parakeet-tdt-0.6b-v3-coreml",
        "folders": ("Preprocessor.mlmodelc", "Encoder.mlmodelc", "Decoder.mlmodelc", "JointDecisionv3.mlmodelc"),
        "files": ("parakeet_vocab.json",),
    },
    "ctc": {
        "repo": "FluidInference/parakeet-ctc-110m-coreml",
        "folders": ("MelSpectrogram.mlmodelc", "AudioEncoder.mlmodelc"),
        "files": ("tokenizer.json", "vocab.json", "config.json"),
    },
}


def main():
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] not in MODELS):
        print("usage: fetch-parakeet.py <cache-dir> [tdt|ctc]", file=sys.stderr)
        return 2
    dest = os.path.abspath(sys.argv[1])
    model = MODELS[sys.argv[2] if len(sys.argv) == 3 else "tdt"]
    repo = model["repo"]

    def needed(path):
        return path in model["files"] or any(path.startswith(folder + "/") for folder in model["folders"])

    os.makedirs(dest, exist_ok=True)
    tree = f"https://huggingface.co/api/models/{repo}/tree/main?recursive=1"
    with urllib.request.urlopen(tree, timeout=60) as response:
        listing = json.load(response)
    files = [item for item in listing if item.get("type") != "directory" and needed(item.get("path", ""))]
    if len(files) < len(model["folders"]) + len(model["files"]):
        print(f"Hub listing did not include the runtime files ({len(files)})", file=sys.stderr)
        return 1
    total = sum(item.get("size") or 0 for item in files)
    print(f"runtime set {total / 1e6:.1f} MB, {len(files)} files")
    for item in files:
        path = item["path"]
        size = item.get("size") or 0
        target = os.path.join(dest, path)
        if os.path.isfile(target) and os.path.getsize(target) == size:
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        url = f"https://huggingface.co/{repo}/resolve/main/{path}"
        partial = target + ".partial"
        print(f"fetch {path}")
        subprocess.run(
            ["curl", "-fsSL", "--http1.1", "--retry", "5", "--retry-all-errors", "--retry-delay", "2", "-C", "-", "-o", partial, url],
            check=True,
        )
        os.replace(partial, target)
        got = os.path.getsize(target)
        if size and got != size:
            print(f"{path} is {got} bytes, Hub says {size}", file=sys.stderr)
            return 1
    for name in model["folders"]:
        if not os.path.isdir(os.path.join(dest, name)):
            print(f"missing {name}", file=sys.stderr)
            return 1
    for name in model["files"]:
        target = os.path.join(dest, name)
        if not os.path.isfile(target) or os.path.getsize(target) == 0:
            print(f"missing {name}", file=sys.stderr)
            return 1
    print(dest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
