#!/usr/bin/env python3
"""
Generate the $readmemh stimulus and expected results the testbenches read from vectors/.

What it writes
--------------
Each lab's vectors/ directory, with the sizes and widths the RTL declares. The files are committed;
tools/run_sims.py regenerates them before every run, and the repository's checks confirm that the
regenerated files match the committed ones.

  09-cnn-accelerator   the course-provided network and MNIST images
                       (09-cnn-accelerator/reference/mnist_cnn.npz), written in the order the RTL
                       reads them, plus the predictions of the RTL-exact golden model in
                       tools/cnn_reference.py for the testbench to check against
  08-sobel-filter      a synthetic 102x102 test pattern and its |Gx|+|Gy| reference image
  04-memory-controller sram/: random SRAM contents and the packed result the controller must
                       produce; bram/: the $readmemh form of the committed .coe and its
                       running prefix sum

Usage
-----
    python tools/gen_vectors.py            # write vectors next to each testbench
    python tools/gen_vectors.py --seed 7   # different, still deterministic, memory data
    python tools/gen_vectors.py --check    # print geometry only, write nothing
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def write_hex(path: Path, values, nibbles: int) -> None:
    """Write one unsigned value per line, zero-padded to `nibbles` hex digits."""
    path.parent.mkdir(parents=True, exist_ok=True)
    mask = (1 << (nibbles * 4)) - 1
    with path.open("w", newline="\n") as fh:
        for v in values:
            fh.write(f"{v & mask:0{nibbles}x}\n")
    print(f"  {path.relative_to(REPO).as_posix()}  ({len(values)} x {nibbles * 4}-bit)")


def rand_i8(rng: random.Random, n: int):
    """Signed 8-bit values, written as two's-complement hex."""
    return [rng.randint(-128, 127) for _ in range(n)]


# ---------------------------------------------------------------------------
# 09-cnn-accelerator  --  tb_cnn_fsm.v
# ---------------------------------------------------------------------------
# The course-provided network (reference/mnist_cnn.npz) is written in the order the RTL reads it:
#   input_run<r>_flatten.hex    run r of tb_cnn_fsm (r = 0..9): 3 images stacked vertically,
#                               28x84 = 2352 bytes, row-major (images 3r..3r+2 of reference/mnist_cnn.npz)
#   conv_weight_flatten.hex     conv1 (8x1x3x3) then conv2 (16x8x3x3), row-major = 1224
#   fc1_weight_flatten_<k>.hex  FC weights for class k, 2304 bytes in (channel, row, col)
#   expected_predictions.hex    rtl-model prediction for each of the 30 images
#   expected_conv2_run0.hex     rtl-model Conv2 output for run 0, laid out like the 16
#                               sram_conv2_result memories: channel k at k*576 + row*24 + col,
#                               24-bit words holding image i in byte i
# tools/cnn_reference.py holds the golden model.
CNN_BATCH = 3
CNN_RUNS = 10


def gen_cnn(out: Path) -> None:
    import numpy as np
    sys.path.insert(0, str(REPO / "tools"))
    import cnn_reference as ref

    print("09-cnn-accelerator (tb_cnn_fsm.v):")
    x, w1, w2, wf, _ = ref.load()
    images = x[:CNN_BATCH * CNN_RUNS]
    for r in range(CNN_RUNS):
        batch = images[r * CNN_BATCH:(r + 1) * CNN_BATCH]
        write_hex(out / f"input_run{r}_flatten.hex", batch.reshape(-1).tolist(), 2)
    write_hex(out / "conv_weight_flatten.hex", np.concatenate([w1.reshape(-1), w2.reshape(-1)]).tolist(), 2)
    for k in range(10):
        write_hex(out / f"fc1_weight_flatten_{k}.hex", wf[k].tolist(), 2)
    write_hex(out / "expected_predictions.hex", ref.rtl_predictions(images, w1, w2, wf).tolist(), 1)

    # Conv2 output of run 0 (images 0-2), shape (3, 16, 24, 24), packed as the RTL stores it
    conv2 = ref.requant_rtl(ref.conv3x3(ref.requant_rtl(ref.conv3x3(images[:CNN_BATCH, None], w1)), w2))
    words = conv2[0] | (conv2[1] << 8) | (conv2[2] << 16)
    write_hex(out / "expected_conv2_run0.hex", words.reshape(-1).tolist(), 6)


# ---------------------------------------------------------------------------
# 08-sobel-filter  --  tb_memory_ctrlr.v / tb_top_memory_ctrlr.v
# ---------------------------------------------------------------------------
# fake_image is declared [0:102*102-1], 8-bit: a 102x102 padded frame whose
# 100x100 interior is what the Sobel datapath produces output for.
SOBEL_W = SOBEL_H = 102


def gen_sobel(out: Path) -> None:
    print("08-sobel-filter (tb_memory_ctrlr.v, tb_top_memory_ctrlr.v):")
    # A deterministic pattern with real edges, so filter output is meaningful
    # rather than noise: nested rectangles plus a diagonal.
    img = []
    for y in range(SOBEL_H):
        for x in range(SOBEL_W):
            v = 32
            if 20 <= x < 80 and 20 <= y < 80:
                v = 160
            if 35 <= x < 65 and 35 <= y < 65:
                v = 96
            if abs(x - y) < 3:
                v = 224
            img.append(v)
    write_hex(out / "fake_image.hex", img, 2)

    # Golden Sobel over the 100x100 interior: |Gx| + |Gy| saturated to 8 bits,
    # matching the datapath's gradient approximation.
    gx_k = ((-1, 0, 1), (-2, 0, 2), (-1, 0, 1))
    gy_k = ((-1, -2, -1), (0, 0, 0), (1, 2, 1))
    ref = []
    for y in range(1, SOBEL_H - 1):
        for x in range(1, SOBEL_W - 1):
            gx = gy = 0
            for j in range(3):
                for i in range(3):
                    p = img[(y - 1 + j) * SOBEL_W + (x - 1 + i)]
                    gx += gx_k[j][i] * p
                    gy += gy_k[j][i] * p
            ref.append(min(abs(gx) + abs(gy), 255))
    write_hex(out / "sobel_expected.hex", ref, 2)


# ---------------------------------------------------------------------------
# 04-memory-controller/sram  --  tb_memory_ctrlr.v
# ---------------------------------------------------------------------------
# SRAM1 is 16-bit x 256 (init_memory.hex); SRAM2 is 32-bit x 192
# (answer_memory.hex). memory_ctrlr.v packs them in two phases:
#
#   Phase 1: for i in 0..63    SRAM2[191 - i] = {SRAM1[2i], SRAM1[2i+1]}
#   Phase 2: for c in 128..255, j = c - 128
#              c even -> SRAM2[j] = {16'h0000, SRAM1[c]}
#              c odd  -> SRAM2[j] = {SRAM1[c], 16'h0000}
SRAM1_N, SRAM2_N = 256, 192


def gen_mem_sram(rng: random.Random, out: Path) -> None:
    print("04-memory-controller/sram (tb_memory_ctrlr.v):")
    src = [rng.randint(0, 0xFFFF) for _ in range(SRAM1_N)]
    write_hex(out / "init_memory.hex", src, 4)
    dst = [0] * SRAM2_N
    for i in range(64):
        dst[191 - i] = (src[2 * i] << 16) | src[2 * i + 1]
    for c in range(128, 256):
        dst[c - 128] = src[c] if c % 2 == 0 else (src[c] << 16)
    write_hex(out / "answer_memory.hex", dst, 8)


# ---------------------------------------------------------------------------
# 04-memory-controller/bram  --  tb_top_memory_wrapper.v
# ---------------------------------------------------------------------------
# The stimulus is the course's initialize_memory.coe, which seeds the BRAM, and the expected
# output follows from it: memory_ctrlr.v walks the BRAM accumulating a running total into a 16-bit
# register and writes it back:
#
#   accum <= accum + doutb;  mem[cursor] <= accum + doutb
#
# so answer[i] = (sum of coe[0..i]) mod 2**16.
#
# Every entry of the course's .coe is 0x0001, so a controller that read the same stale entry every
# time would still produce the right sums. The testbench therefore also runs a second RAM seeded
# with random 16-bit values (random_memory.hex), whose sums also wrap around 2**16.
BRAM_N = 256


def parse_coe(path: Path):
    """Read a Vivado .coe memory-initialization vector (radix 16)."""
    body = path.read_text().split("memory_initialization_vector=", 1)[1]
    return [int(tok, 16) for tok in
            (t.strip() for t in body.replace(";", ",").split(","))
            if tok]


def running_sum(values):
    acc, out = 0, []
    for v in values:
        acc = (acc + v) & 0xFFFF
        out.append(acc)
    return out


def gen_mem_bram(rng: random.Random, out: Path, coe: Path) -> None:
    print("04-memory-controller/bram (tb_top_memory_wrapper.v):")
    if not coe.exists():
        print(f"  SKIP - {coe.name} not found")
        return
    src = parse_coe(coe)
    if len(src) != BRAM_N:
        print(f"  WARNING - expected {BRAM_N} entries, .coe has {len(src)}")
    write_hex(out / "initialize_memory.hex", src, 4)   # $readmemh form of the .coe, loaded by bram.v
    write_hex(out / "answer_memory.hex", running_sum(src), 4)
    rand = [rng.randrange(1 << 16) for _ in range(BRAM_N)]
    write_hex(out / "random_memory.hex", rand, 4)
    write_hex(out / "random_answer.hex", running_sum(rand), 4)


# ---------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--seed", type=int, default=0,
                    help="PRNG seed; the same seed always gives the same vectors")
    ap.add_argument("--check", action="store_true",
                    help="print the geometry and exit without writing files")
    args = ap.parse_args()

    if args.check:
        print("Vector geometry (read from the RTL/testbench declarations):")
        print(f"  CNN  input   {CNN_RUNS} runs x {CNN_BATCH} images x 28x28, 8-bit signed")
        print(f"  CNN  conv    1224 x 8-bit signed (conv1 72 + conv2 1152)")
        print(f"  CNN  fc      10 banks x 2304 x 8-bit signed")
        print(f"  Sobel image  {SOBEL_W}x{SOBEL_H} x 8-bit unsigned")
        print(f"  SRAM pack    {SRAM1_N} x 16-bit -> {SRAM2_N} x 32-bit")
        print(f"  BRAM sum     prefix sums of initialize_memory.coe and of random data -> {BRAM_N} x 16-bit")
        return

    rng = random.Random(args.seed)
    print(f"Generating vectors (seed={args.seed})\n")
    gen_cnn(REPO / "09-cnn-accelerator" / "vectors")
    gen_sobel(REPO / "08-sobel-filter" / "vectors")
    gen_mem_sram(rng, REPO / "04-memory-controller" / "sram" / "vectors")
    bram = REPO / "04-memory-controller" / "bram" / "vectors"
    gen_mem_bram(rng, bram, bram / "initialize_memory.coe")
    print("\nDone. Point each testbench $readmemh at the vectors/ directory "
          "beside it.")


if __name__ == "__main__":
    main()
