#!/usr/bin/env python3
"""
Golden model for the 09-cnn-accelerator network: Conv(8) -> ReLU -> Conv(16) -> ReLU ->
MaxPool 2x2 -> FC(2304 -> 10) -> argmax, on 28x28 MNIST images in signed 8-bit.

After each convolution and after the FC layer, values return to 8 bits as the course specifies:
the 10 least significant bits are dropped and the result is saturated to [-128, 127]. This
reproduces the course-provided reference logits (`output` in reference/mnist_cnn.npz) exactly. It
is also what the RTL computes (relu.v after each convolution, argmax.v for the FC logits, ties
going to the lowest class index as in numpy's argmax), so the simulation is checked against it.

    python tools/cnn_reference.py                 # confirm the model matches the reference logits
    python tools/cnn_reference.py --predict 0 6   # predictions for images 0..5

The data (course-provided weights, 10,000 unlabeled MNIST images and reference logits) is read from
09-cnn-accelerator/reference/.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

REF = Path(__file__).resolve().parent.parent / "09-cnn-accelerator" / "reference"


def load():
    d = np.load(REF / "mnist_cnn.npz")
    return (d["input"].astype(np.int64)[:, 0], d["layer1"].astype(np.int64),
            d["layer2"].astype(np.int64), d["fc1"].astype(np.int64), d["output"].astype(np.int64))


def conv3x3(a: np.ndarray, w: np.ndarray) -> np.ndarray:
    """Valid 3x3 cross-correlation: (N, Cin, H, W) x (Cout, Cin, 3, 3) -> (N, Cout, H-2, W-2)."""
    win = np.lib.stride_tricks.sliding_window_view(a, (3, 3), axis=(2, 3))
    return np.einsum("nchwij,ocij->nohw", win, w, optimize=True)


def maxpool2(a: np.ndarray) -> np.ndarray:
    n, c, h, w = a.shape
    return a.reshape(n, c, h // 2, 2, w // 2, 2).max(axis=(3, 5))


def requant(v: np.ndarray) -> np.ndarray:
    return np.clip(v >> 10, -128, 127)


def conv_layers(x, w1, w2):
    """Conv1 -> ReLU -> Conv2 -> ReLU, each returned to 8 bits: (N, 28, 28) -> (N, 16, 24, 24)."""
    a = np.maximum(requant(conv3x3(x[:, None], w1)), 0)
    return np.maximum(requant(conv3x3(a, w2)), 0)


def logits(x, w1, w2, wf):
    return requant(maxpool2(conv_layers(x, w1, w2)).reshape(len(x), -1) @ wf.T)


def predictions(x, w1, w2, wf, batch: int = 1000) -> np.ndarray:
    return np.concatenate([logits(x[i:i + batch], w1, w2, wf).argmax(axis=1) for i in range(0, len(x), batch)])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--predict", nargs=2, type=int, metavar=("FIRST", "COUNT"), help="print predictions")
    args = ap.parse_args()
    x, w1, w2, wf, ref = load()

    if args.predict:
        first, count = args.predict
        print(predictions(x[first:first + count], w1, w2, wf).tolist())
        return

    out = np.concatenate([logits(x[i:i + 1000], w1, w2, wf) for i in range(0, len(x), 1000)])
    exact = int((out == ref).all(axis=1).sum())
    print(f"model reproduces the reference logits for {exact}/{len(x)} images")
    if exact != len(x):
        sys.exit(1)


if __name__ == "__main__":
    main()
