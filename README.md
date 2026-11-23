# FPGA Accelerator Labs — Verilog to a CNN on Spartan-7 and Zynq

[![checks](https://github.com/h23yonsei/fpga-cnn-accelerator-labs/actions/workflows/checks.yml/badge.svg)](https://github.com/h23yonsei/fpga-cnn-accelerator-labs/actions/workflows/checks.yml)

Nine Verilog labs that build from combinational logic to an MNIST CNN accelerator in programmable
logic, covering the parts an accelerator needs along the way: block RAM control, FIFOs and line
buffers, a UART link, custom AXI IP, and a streaming 2-D convolution. The pipelined CNN core meets
timing at 100 MHz, where the version submitted for the course misses even 50 MHz.

All 21 testbenches run from a clone with one command, in Vivado's simulator or in the free Icarus
Verilog, and each result is checked automatically. Every board design is built with Vivado from
scripts in `tools/`.

The labs are the assignments of EEE3551 Intelligent System Design and Applications at Yonsei
University, Spring 2025. Each lab's README marks what came with the course: the port lists of the
modules to write (labs 03–06), lab 04's SRAM model, top levels and block RAM initialization file,
lab 05's FIFO, lab 06's top-level skeleton, its UART, clocking, reset and synchronizer modules and
test image, lab 07's packing controller, top level and answer file, the PYNQ-Z2 constraints of labs
08 and 09, lab 08's host notebook and test image, and lab 09's trained weights, MNIST images and
reference outputs. Six testbenches, lab 08's FIFO and the host notebooks of labs 06 and 07 are built
on the course's versions, and the register IPs on Vivado's AXI4-Lite peripheral template. The rest
of the RTL and testbenches, the golden models, lab 09's host notebook, and the build and simulation
scripts were written here.

## Labs

| Lab | Design | Target |
|-----|--------|--------|
| [`01-decoder-74ls138`](01-decoder-74ls138/) | 74LS138 3-to-8 decoder (gate-level and behavioral), 4-to-16 decoder | Simulation |
| [`02-counter-and-fsm`](02-counter-and-fsm/) | Up/down counter and IDLE/UP/DOWN/READY controller with clock divider, debouncers, seven-segment display | Arty S7-50 |
| [`03-vending-machine`](03-vending-machine/) | Three-item vending machine with coin, filling and selling modes | Arty S7-50 |
| [`04-memory-controller`](04-memory-controller/) | Memory controllers for an SRAM model and a Block Memory Generator core | Simulation |
| [`05-fifo-line-buffer`](05-fifo-line-buffer/) | Block-RAM FIFO and three-row line buffer | Simulation |
| [`06-uart-loopback`](06-uart-loopback/) | UART receive, store in block RAM, transmit back | Arty S7-50 |
| [`07-axi-custom-ip`](07-axi-custom-ip/) | Memory controller as a custom IP in a Zynq block design | PYNQ-Z2 |
| [`08-sobel-filter`](08-sobel-filter/) | Sobel edge filter over line buffers, as a Zynq IP | PYNQ-Z2 |
| [`09-cnn-accelerator`](09-cnn-accelerator/) | MNIST CNN: Conv → ReLU → Conv → ReLU → MaxPool → FC → ArgMax | PYNQ-Z2 |

Each lab keeps its sources in `rtl/`, `tb/`, `vectors/`, `constraints/`, and, for the Zynq labs,
`ip/` and `bd/`; `host/` holds the PC- or PS-side notebook of a board test and, in labs 06–08, its
test image or answer file.

## Simulation

```bash
python tools/run_sims.py            # every lab
python tools/run_sims.py 08 09      # selected labs
python tools/run_sims.py --vivado C:/Xilinx/Vivado/2022.1
python tools/run_sims.py --sim icarus
```

`run_sims.py` regenerates the test vectors, then compiles, elaborates and runs each testbench in
`build/sim/` and reports whether it passed: 20 testbenches check their own results, and for
`tb_loopback` the script compares the bytes sent with the bytes echoed back. It uses Vivado's
`xvlog` / `xelab` / `xsim` when Vivado is installed and Icarus Verilog (`iverilog` / `vvp`,
version 12) otherwise. What each testbench checks:

| Lab | Testbench | Check |
|-----|-----------|-------|
| 01 | `tb_decoder_74ls138`, `tb_decoder_4to16` | Full truth tables, 64 input combinations each |
| 02 | `tb_top_counter` | 50 Hz divider period; counting, both limits and reset; both display digits |
| 02 | `tb_top_fsm` | Divider period; every state transition, count checked on each 1 Hz tick |
| 03 | `tb_vending_machine` | Balance, stock limits and LEDs through filling, coin and selling sequences, `SW3` off and on, and the `SW0` reset |
| 04 | `tb_memory_ctrlr` | All 192 packed output words |
| 04 | `tb_top_memory_wrapper` | All 256 running-sum entries in block RAM, for the course's data and for random data |
| 05 | `tb_fifo`, `tb_line_buffer` | Read order and full/empty flags; line buffer read-back over two passes, with a refused write and extra reads |
| 06 | `tb_loopback` | 100 of 100 bytes echoed back in order over the UART |
| 06 | `tb_memory_control` | The controller alone at the board's 16,384-byte depth: LED after the last byte, every byte stored and returned in order |
| 07 | `tb_top_memory_ctrlr` | All 192 output words match the course's answer file |
| 07 | `tb_csr` | Register IP over AXI4-Lite: one start pulse per write of 1, start bit cleared after it, `done` readable |
| 08 | `tb_sobel_window` | 193 of 193 window outputs match \|Gx\| + \|Gy\| |
| 08 | `tb_line_buffer`, `tb_memory_ctrlr` | Read-back; all 10,000 output pixels written |
| 08 | `tb_top_memory_ctrlr` | All 10,000 output pixels match the reference edge image |
| 09 | `tb_relu` | Return to 8 bits and ReLU on 17,180 sums, saturation included |
| 09 | `tb_maxpool_fc_argmax` | ArgMax over 8-bit logits in two frames, with saturated and tied logits |
| 09 | `tb_cnn_fsm` | 30 MNIST images with the trained weights; all 30 predictions and all 9,216 Conv2 result words match the golden model, and every FC weight is read at its pixel's address |
| 09 | `tb_csrr` | Register IP over AXI4-Lite, including the three predictions |

All 21 testbenches pass in Icarus Verilog 12, which the repository runs on every push (the badge
above). They also pass in Vivado 2022.1's simulator.

### Test data

Stimulus is either synthetic with a computed expected result (the Sobel test image and its edge
image, the memory controller patterns), or taken from course-provided data: the lab 04 block RAM
initialization file, the lab 06 test image (scaled down to 64×64), the lab 07 answer file, and for
lab 09 the trained weights, 10,000 unlabeled MNIST images and the reference outputs in
`09-cnn-accelerator/reference/`. `tools/gen_vectors.py` writes the vectors of labs 04, 08 and 09
from these; the other labs' testbenches compute their expected values themselves or read the files
committed in their `vectors/`.

`tools/cnn_reference.py` is the golden model for lab 09. Implemented to the course specification, it
reproduces the course's reference logits exactly on all 10,000 images. The RTL computes the same
arithmetic (see the [lab README](09-cnn-accelerator/README.md#golden-model)), and the simulation is
checked against the model.

### Block RAM models

The course projects use Block Memory Generator cores, whose `.xci` configurations are not part of
this repository. Instead, each lab's `rtl/` contains a small Verilog model of every memory with the
geometry, operating mode and read latency the course's handouts specify, or, for the memories they
leave open (lab 08's FIFO storage and lab 09's memories), those of the design submitted for the
course. The models are written in Vivado's RAM inference templates, so the same file simulates in
xsim and synthesizes to block RAM.

## Hardware builds

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs <counter|fsm|vending|uart|cnn>
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs <axi|sobel|cnn>
```

`build_hw.tcl` runs synthesis, implementation and (for board designs) bitstream generation from the
lab sources. `build_bd.tcl` re-packages a Zynq lab's custom IP, imports its block design into a new
project, upgrades the Xilinx IP, and implements it through bitstream and an `.xsa`, writing the
bitstream and hardware handoff under the names the lab's notebook loads. Output goes to `build/`.
The reports of the builds below are committed in each lab's `reports/`; those of the block-design
builds are named `system_*.rpt`.

| Design | Part | LUTs | FFs | BRAM tiles | DSP | Worst setup slack |
|--------|------|-----:|----:|-----------:|----:|------------------:|
| Counter | xc7s50 | 20 | 31 | 0 | 0 | +5.576 ns @ 100 MHz |
| FSM controller | xc7s50 | 31 | 65 | 0 | 0 | +5.148 ns @ 100 MHz |
| Vending machine | xc7s50 | 98 | 51 | 0 | 0 | +5.552 ns @ 100 MHz |
| UART loopback | xc7s50 | 104 | 118 | 4 | 0 | +7.937 ns @ 100 MHz |
| CNN core (out of context) | xc7z020 | 7,811 | 11,497 | 31.5 | 174 | +0.839 ns @ 100 MHz |
| CNN system (block design) | xc7z020 | 20,517 | 22,811 | 31.5 | 174 | +0.373 ns @ 100 MHz |
| AXI memory controller (block design) | xc7z020 | 6,301 | 7,554 | 5 | 0 | +2.327 ns @ 100 MHz |
| Sobel filter (block design) | xc7z020 | 6,524 | 7,514 | 11.5 | 0 | +1.224 ns @ 100 MHz |

The Arty S7 designs divide the 100 MHz board clock with flip-flops, to 50 MHz in the UART loopback
and to 50 Hz in the others (and also to 1 Hz in the FSM), and run their logic on the divided clocks.
Their constraints declare these as generated clocks, so every register is timed; each design's worst
slack is on a path captured at 100 MHz.

The CNN core submitted for the course misses even 50 MHz (−6.456 ns: every dot product is one
combinational block, 33 logic levels deep), and the submitted Sobel filter misses 100 MHz. Both are
pipelined here, as the [CNN](09-cnn-accelerator/README.md#changes-from-the-course-submission) and
[Sobel](08-sobel-filter/README.md#changes-from-the-course-submission) READMEs describe, and the CNN
system runs on the PS's 100 MHz clock without the clocking wizard of the submitted block design.

No design has been run on a board. The notebooks for the board tests of labs 07 and 09 have been run
only against Python stand-ins for their overlays.

## Where this differs from the course submissions

Faults that this repository corrects in the designs submitted for the course:

- `02` FSM: no undriven, unconstrained output port, which bitstream generation rejects.
- `04` block-RAM controller: every entry is written, and each read returns the entry being summed.
  The course's all-0x0001 data cannot reveal stale reads, so the testbench also uses random data.
- `06` loopback: the byte counters reach the board design's full 16,384 bytes.
- `08` Sobel: no latches in the adder, and no incomplete sensitivity list in `make_pixel`.
- `09` Conv1: each result is written at its own pixel; the submitted design writes it one pixel
  early, which shifts every feature map and changes predictions.
- `09` ArgMax: the FC sums become 8-bit logits before they are compared, as the course specifies;
  the submitted design compares them at full width, which picks a different class on 261 of the
  10,000 images.
- `09` FC weights: the last pooled pixel is multiplied by its own weights; the submitted design
  reads those of the first pooled pixel, which changes 3 of the 10,000 predictions.

The Vivado builds show two of these fixes: bitstream generation accepts the `02` FSM, and the `08`
Sobel build's utilization report lists no latches. Testbenches cover the other fixes. Every
testbench's result is checked automatically, its stimulus changes clear of the clock edge the design
samples, and an unknown value counts as a failure.

## Requirements

Vivado 2022.1 (the block designs were saved with 2021.1 and are upgraded on import) and Python 3
with the packages in `requirements.txt`. The simulations alone need only Python, NumPy and Icarus
Verilog 12 or later (`apt install iverilog`, `brew install icarus-verilog`). The notebooks of labs
07–09 run in the PYNQ-Z2's own Jupyter, on the board's PYNQ image.

## License

Released under the [MIT License](LICENSE). The course-provided material listed above, marked in each
lab's README, remains the course's.
