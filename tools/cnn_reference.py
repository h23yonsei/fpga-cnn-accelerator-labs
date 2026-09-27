#!/usr/bin/env python3
"""
Golden models for the 09-cnn-accelerator network: Conv(8) -> ReLU -> Conv(16) -> ReLU ->
MaxPool 2x2 -> FC(2304 -> 10) -> argmax, on 28x28 MNIST images in signed 8-bit.

Two models are implemented, because the course specification and the RTL differ in how they
return to 8 bits after each layer:

  spec   drop the 10 LSBs, saturate to [-128, 127] (also applied to the FC logits).
         This reproduces the course-provided reference logits (`output` in reference/mnist_cnn.npz)
         exactly.
  rtl    what the Verilog does: ReLU, then keep bits [16:10] with the MSB forced to 0; the FC
         accumulator is compared un-shifted in argmax.v (ties resolve to the lowest index).
         This is the model the simulation is checked against.

    python tools/cnn_reference.py                 # agreement of the rtl model with the reference
    python tools/cnn_reference.py --check-spec    # also confirm the spec model reproduces the reference
    python tools/cnn_reference.py --predict 0 6   # rtl-model predictions for images 0..5

The data (course-provided weights, 10,000 unlabeled MNIST images and reference logits) is read from
09-cnn-accelerator/reference/.
"""

from __future__ import annotations

import argparse
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


def requant_spec(v: np.ndarray) -> np.ndarray:
    return np.clip(v >> 10, -128, 127)


def requant_rtl(v: np.ndarray) -> np.ndarray:
    return (np.maximum(v, 0) >> 10) & 0x7F


def spec_logits(x, w1, w2, wf):
    a = np.maximum(requant_spec(conv3x3(x[:, None], w1)), 0)
    a = np.maximum(requant_spec(conv3x3(a, w2)), 0)
    return requant_spec(maxpool2(a).reshape(len(x), -1) @ wf.T)


def rtl_fc(x, w1, w2, wf):
    a = requant_rtl(conv3x3(x[:, None], w1))
    a = requant_rtl(conv3x3(a, w2))
    return maxpool2(a).reshape(len(x), -1) @ wf.T


def rtl_predictions(x, w1, w2, wf, batch: int = 1000) -> np.ndarray:
    return np.concatenate([rtl_fc(x[i:i + batch], w1, w2, wf).argmax(axis=1) for i in range(0, len(x), batch)])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check-spec", action="store_true", help="confirm the spec model reproduces the reference logits")
    ap.add_argument("--predict", nargs=2, type=int, metavar=("FIRST", "COUNT"), help="print rtl-model predictions")
    args = ap.parse_args()
    x, w1, w2, wf, ref = load()

    if args.predict:
        first, count = args.predict
        print(rtl_predictions(x[first:first + count], w1, w2, wf).tolist())
        return

    if args.check_spec:
        logits = np.concatenate([spec_logits(x[i:i + 1000], w1, w2, wf) for i in range(0, len(x), 1000)])
        exact = int((logits == ref).all(axis=1).sum())
        print(f"spec model reproduces the reference logits for {exact}/{len(x)} images")

    pred = rtl_predictions(x, w1, w2, wf)
    agree = int((pred == ref.argmax(axis=1)).sum())
    print(f"rtl model agrees with the reference prediction on {agree}/{len(x)} images ({agree / len(x):.2%})")


if __name__ == "__main__":
    main()
