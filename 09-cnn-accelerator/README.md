# CNN Accelerator

An MNIST digit classifier implemented entirely in programmable logic on a Zynq. The PS loads the
images and weights into block RAM and starts the accelerator, which classifies three images per
run and reports three predicted digits.

## Network

```text
Input (1, 28, 28) → Conv1 3×3 (8) → ReLU → Conv2 3×3 (16) → ReLU → MaxPool 2×2 → FC (2304 → 10) → ArgMax
                      (8, 26, 26)          (16, 24, 24)          (16, 12, 12)       (10)
```

All values are signed 8-bit. As the course specifies, each layer's sums return to 8 bits by dropping
their 10 least significant bits and saturating to [−128, 127]. After the convolutions, ReLU then
keeps the results in 0–127; after the FC layer, ArgMax picks the largest of the ten logits, the
lowest class on a tie.

## Design

- **`cnn_fsm`** sequences the whole pipeline over a batch of three 28×28 images, reading inputs and
  weights from block RAM and storing intermediate feature maps in the result memories
  (`sram_conv1_result` ×8 and `sram_conv2_result` ×16).
- **`conv1_layer`** runs the first layer: `conv_slide_reg` forms the 3×3 input window, eight
  `filter_window`s hold the kernels, and eight `conv1_math` blocks compute the dot products.
- **`conv2_layer`** runs the second layer with `filter_window`, `conv2_math` (a nine-term dot
  product per input channel), an eight-way adder and `relu`.
- **`relu`** returns a convolution sum to 8 bits and applies ReLU, for both layers.
- **`mult8x8`** is the signed 8 × 8 multiplier every layer uses, with registered inputs, product
  and output, so each multiply fits inside one DSP48 block.
- **`maxpool_fc_argmax`**, one per image, chains `maxpool`, `fc_layer` and `argmax`, which returns
  the FC sums to 8-bit logits before comparing them.
- **`top_cnn`** holds the controller and the input, convolution weight and ten FC weight memories.
  Port A of each is brought out for the PS; port B belongs to the accelerator.
- **`csrr`** is an AXI4-Lite register IP: writing 1 to bit 0 of register 1 starts a run (the bit
  then clears itself), `done` is readable in bit 0 of register 0, and the three predictions in
  registers 3–5.

The block design (`bd/design_1.bd`) connects the Zynq PS through an AXI SmartConnect to twelve AXI
BRAM controllers (input, convolution weights, ten FC weight rows) and the `csrr` IP, together with
slice, concat and constant cells and a processor reset block, through which SW0 resets the PL, as
Assignment 4 asks. The saved design clocks the accelerator at 50 MHz through a clocking wizard;
`tools/build_bd.tcl` removes the wizard, so the whole design runs on the PS's 100 MHz clock (see
[Build](#build)).

## Files

| Path | Description |
|------|-------------|
| `rtl/top_cnn.v` | IP top level |
| `rtl/cnn_fsm.v` | Pipeline controller |
| `rtl/conv1_layer.v`, `rtl/conv1_math.v` | First convolution layer |
| `rtl/conv2_layer.v`, `rtl/conv2_math.v` | Second convolution layer |
| `rtl/conv_slide_reg.v`, `rtl/filter_window.v` | 3×3 input window and kernel registers, used by both layers |
| `rtl/mult8x8.v` | Registered 8 × 8 multiplier |
| `rtl/relu.v`, `rtl/maxpool.v`, `rtl/fc_layer.v`, `rtl/argmax.v`, `rtl/maxpool_fc_argmax.v` | Return to 8 bits and ReLU, pooling, classifier |
| `rtl/sram_*.v` | Behavioral models of the Block Memory Generator cores (see each file's header for geometry) |
| `tb/tb_cnn_fsm.v` | Full pipeline on 30 course images with the trained weights |
| `tb/tb_maxpool_fc_argmax.v` | MaxPool → FC → ArgMax on two small frames, with saturated and tied logits |
| `tb/tb_relu.v` | Return to 8 bits and ReLU against the course's rule |
| `tb/tb_csrr.v` | The register IP through its AXI4-Lite port |
| `vectors/` | Images, weights, expected predictions and the expected Conv2 results, generated from `reference/` |
| `reference/mnist_cnn.npz` | Course-provided trained weights, 10,000 unlabeled MNIST images and the course's reference logits |
| `ip/csrr_1.0/hdl/` | Register IP sources (Vivado's AXI4-Lite peripheral template with the control logic added) |
| `bd/design_1.bd` | Block design |
| `constraints/pynq_z2.xdc` | PYNQ-Z2 constraints (course-provided) |
| `constraints/cnn_ooc.xdc` | 100 MHz clock constraints for building `top_cnn` on its own |
| `reports/` | Utilization and timing reports: the core build, and `system_*.rpt` from the block-design build |
| `host/cnn_driver.ipynb` | PS driver for the board test: loads the weights, classifies the 10,000 images three per run, reports the latency and compares the predictions with the reference |

## Golden model

`tools/cnn_reference.py` implements the network as the course specifies it, returning each layer to
8 bits by shifting right by 10 and saturating to [−128, 127]. It reproduces the course's reference
logits exactly for all 10,000 images:

```bash
python tools/cnn_reference.py
```

The RTL computes the same arithmetic, so the simulation is checked against this model. The data
carries no labels, so no classification accuracy is quoted.

## Verification

```bash
python tools/run_sims.py 09
```

- **`tb_cnn_fsm`** loads the course's trained weights and runs the whole pipeline ten times on the
  first 30 images, checking every prediction against the golden model; in images 10 and 28 two
  classes share the highest logit, and the lower one must win. After the first run it also compares
  all 16 Conv2 result memories (9,216 words) with the model's Conv2 output, so a feature-map value
  stored at the wrong address fails even when the predicted digit survives it. And in every run the
  ten FC weight memories must be read together, once per pooled pixel, at addresses 0 to 2,303 in
  order: a weight read from the wrong address changes no prediction where its pixel is 0.
- **`tb_maxpool_fc_argmax`** pools two rows of 24 pixels, applies one fixed weight per class and
  checks ArgMax over the resulting logits in two frames: in one, logits saturate at both ends; in
  the other, three classes reach 127 and the lowest must win, although another has the largest
  full-width sum.
- **`tb_relu`** compares `relu` with the course's rule on 17,180 sums: both ends of the 24-bit
  range, every sum from −2,048 to 2,048, the sums around the start of saturation and 10,000 random
  ones. No sum on the course's data reaches the saturation range, so this is where that path is
  checked.
- **`tb_csrr`** drives the `csrr` IP through AXI4-Lite transactions, as the PS does: one `start`
  pulse per write of 1, the bit reading back 0 afterwards, `done` in register 0 and the predictions
  in registers 3–5.

`host/cnn_driver.ipynb` has not been run on a board, only against a Python stand-in for the overlay
that computes the golden model, where all 10,000 predictions matched the reference.

## Build

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs cnn
```

Synthesizes and implements the accelerator core (`top_cnn`) out of context on the Zynq-7020
(`xc7z020clg400-1`) with every clock at 100 MHz (`constraints/cnn_ooc.xdc`). Reports are written to
`build/hw/cnn/`; the ones in `reports/` come from Vivado 2022.1.

```bash
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs cnn
```

Builds the complete system: re-packages `top_cnn` and `csrr`, imports the block design, removes its
clocking wizard so `FCLK_CLK0` (100 MHz) drives the accelerator, the BRAM controllers, the
interconnect and the register IP, and implements it through bitstream and `.xsa` in `build/bd/cnn/`.
It also writes the bitstream and hardware handoff as `cnn.bit` and `cnn.hwh`, the names the driver
loads. For the board test, copy both to the board with `host/cnn_driver.ipynb` and
`reference/mnist_cnn.npz`, set SW0 on (it is the PL's active-low reset) and run the notebook; it
reports the latency for all 10,000 images as Assignment 4 defines it.

| | Core (out of context) | Full system (block design) |
|---|---:|---:|
| Clock | 100 MHz | 100 MHz (`FCLK_CLK0`, no clocking wizard) |
| Worst setup slack | +0.839 ns | +0.373 ns |
| LUTs | 7,811 (14.7%) | 20,517 (38.6%) |
| Flip-flops | 11,497 (10.8%) | 22,811 (21.4%) |
| Block RAM tiles | 31.5 (27 × RAMB36, 9 × RAMB18) | 31.5 |
| DSP48 | 174 (79.1%) | 174 |

In the core the slowest path carries `fc_layer`'s accumulate enable into an FC sum register, mostly
routing (83%) as the enable fans out to 568 loads; in the full system it lies inside the AXI
SmartConnect.

### Changes from the course submission

The core submitted for the course misses even 50 MHz: every dot product is one combinational block,
and the critical path runs from a Conv2 window register through 72 multiplies, both adder trees,
ReLU and a byte-select mux into a result memory (26.1 ns, 33 logic levels, −6.456 ns of slack at
50 MHz, no DSP blocks). Here the arithmetic is a pipeline, with the control that depends on its
timing matched to it:

- **Conv1 (7 cycles).** `conv1_math` multiplies through `mult8x8` (3 cycles) and sums the nine
  products in a registered 9 → 5 → 3 → 2 → 1 tree (4 cycles). `conv1_layer` delays `valid_out` and
  `done` by the same 7 cycles, so each result is written at its own pixel (below).
- **Conv2 (11 cycles).** `conv2_math` is built the same way (7 cycles), followed by a registered
  8 → 4 → 2 → 1 tree (3 cycles) and a registered byte-select output (1 cycle). Valid and write
  enable travel through delay lines of `CONV2_LAT` = 11.
- **FSM.** The Conv2 result memories, the MaxPool read muxes, their read counters and the Conv2
  write address are driven from a delay line of the state, `CONV2_LAT - 1` cycles behind, so a
  result is always written before MaxPool reads it. State comparisons on that delay line are
  registered one-hot bits, and the Conv2 shift-register enable is a replicated register.
- **Weights and FC.** The convolution weight read data is registered before it fans out to the 16
  kernel windows (the load enables are delayed with it). `fc_layer` multiplies through `mult8x8`
  and accumulates three cycles later.
- **MaxPool and ArgMax.** The MaxPool input mux is registered together with its valid, and `argmax`
  runs its ten-way comparison as a tournament over two registered rounds, lower index winning ties.
- **Window taps.** `conv_slide_reg` does not zero the window outside valid positions: both layers
  store a result only when valid, so zeroing would only lengthen the path into the multipliers.
- **Conv1 write position.** The submitted design registers Conv1's write enable but not its data, so
  every result lands one pixel early and every feature map shifts by one position; together with its
  FC comparison and FC weight address (both below), its predictions agree with the course reference
  on 87.78% of the images. Here valid is delayed by exactly the arithmetic's latency.
- **Return to 8 bits.** The submitted design compares the ten FC sums at full width instead of as
  8-bit logits, and keeps bits [16:10] of each convolution sum after ReLU, which wraps instead of
  saturating above 127. Dropping 10 bits makes some FC logits equal, and the course's reference then
  takes the lowest of the tied classes, while the full-width comparison still tells them apart: on
  261 of the 10,000 images it picks a different class (97.39% agreement). No convolution sum on the
  course's data is large enough to saturate. Here every layer returns to 8 bits as the course
  specifies, so the logits equal the reference logits.
- **FC weight address.** The submitted controller returns the FC weight address to 0 in the cycle
  before the last pooled pixel arrives, so that pixel is multiplied by the weights of the first. The
  last pooled pixel is non-zero in 110 of the 10,000 images, and in 3 of them the prediction
  changes. Here the address returns to 0 only at the next start.

`tb_cnn_fsm` checks the pipelined design: all 30 predictions and all 9,216 Conv2 result words match
the golden model, and every run reads each FC weight at its pixel's address.
