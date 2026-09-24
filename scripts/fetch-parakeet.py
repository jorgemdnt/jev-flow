#!/usr/bin/env python3
"""Download the Parakeet v3 files JevFlow runs, not the whole Hub repo."""

import json
import os
import subprocess
import sys
import urllib.request

REPO = "FluidInference/parakeet-tdt-0.6b-v3-coreml"
TREE = f"https://huggingface.co/api/models/{REPO}/tree/main?recursive=1"
PREFIXES = (
    "Preprocessor.mlmodelc/",
    "Encoder.mlmodelc/",
    "Decoder.mlmodelc/",
    "JointDecisionv3.mlmodelc/",
    "parakeet_vocab.json",
)


def needed(path):
    return path == "parakeet_vocab.json" or any(path.startswith(prefix) for prefix in PREFIXES[:-1])


def main():
    if len(sys.argv) != 2:
        print("usage: fetch-parakeet.py <cache-dir>", file=sys.stderr)
        return 2
    dest = os.path.abspath(sys.argv[1])
    os.makedirs(dest, exist_ok=True)
    with urllib.request.urlopen(TREE, timeout=60) as response:
        listing = json.load(response)
    files = [item for item in listing if item.get("type") != "directory" and needed(item.get("path", ""))]
    if len(files) < 5:
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
        url = f"https://huggingface.co/{REPO}/resolve/main/{path}"
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
    for name in ("Preprocessor.mlmodelc", "Encoder.mlmodelc", "Decoder.mlmodelc", "JointDecisionv3.mlmodelc"):
        if not os.path.isdir(os.path.join(dest, name)):
            print(f"missing {name}", file=sys.stderr)
            return 1
    vocab = os.path.join(dest, "parakeet_vocab.json")
    if not os.path.isfile(vocab) or os.path.getsize(vocab) < 1000:
        print("missing parakeet_vocab.json", file=sys.stderr)
        return 1
    print(dest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
