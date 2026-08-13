#!/usr/bin/env python3
"""Measure fixed-frame Rec.601 luma gates for visual proof captures."""

import argparse
import sys
from pathlib import Path

from PIL import Image


def measure(path: Path, dark: int, bright: int) -> tuple[float, float, float]:
    image = Image.open(path).convert("RGB")
    pixels = image.get_flattened_data()
    luma = [(299 * r + 587 * g + 114 * b) // 1000 for r, g, b in pixels]
    count = len(luma)
    mean = sum(luma) / count
    dark_share = 100.0 * sum(value < dark for value in luma) / count
    bright_share = 100.0 * sum(value > bright for value in luma) / count
    return mean, dark_share, bright_share


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", nargs="+", type=Path)
    parser.add_argument("--dark", type=int, required=True)
    parser.add_argument("--bright", type=int, required=True)
    parser.add_argument("--min-mean", type=float, required=True)
    parser.add_argument("--max-dark", type=float, required=True)
    parser.add_argument("--min-bright", type=float, required=True)
    args = parser.parse_args()

    failed = False
    for frame in args.frames:
        mean, dark_share, bright_share = measure(frame, args.dark, args.bright)
        passed = (mean >= args.min_mean and dark_share <= args.max_dark
                  and bright_share >= args.min_bright)
        print("%s %s mean=%.2f dark<%d=%.2f%% bright>%d=%.2f%%"
              % ("PASS" if passed else "FAIL", frame, mean, args.dark,
                 dark_share, args.bright, bright_share))
        failed = failed or not passed
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
