# FPGA Accelerator Labs — Verilog to a CNN on Spartan-7 and Zynq

[![checks](https://github.com/h23yonsei/fpga-cnn-accelerator-labs/actions/workflows/checks.yml/badge.svg)](https://github.com/h23yonsei/fpga-cnn-accelerator-labs/actions/workflows/checks.yml)

Nine Verilog labs that build from combinational logic to an MNIST CNN accelerator in programmable
logic, covering the parts an accelerator needs along the way: block RAM control, FIFOs and line
buffers, a UART link, custom AXI IP, and a streaming 2-D convolution. The pipelined CNN core meets
timing at 100 MHz, where the course's version misses even 50 MHz.

All 18 self-checking testbenches run from a clone with one command, in Vivado's simulator or in the
free Icarus Verilog, and every design is built with Vivado from scripts in `tools/`.

The labs are the assignments of EEE3551 Intelligent System Design and Applications at Yonsei
University, Spring 2025. Each lab's README marks what came with the course — skeleton port lists,
the UART and synchronizer modules and test image in lab 06, the lab 07 answer file, and lab 09's
trained weights, MNIST images and reference outputs — and what was written here: the rest of the
RTL, every testbench, the golden models, and the build and simulation scripts.

## Labs

| Lab | Design | Target |
|-----|--------|--------|
| [`01-decoder-74ls138`](01-decoder-74ls138/) | 74LS138 3-to-8 decoder (gate-level and behavioral), 4-to-16 decoder | simulation |
| [`02-counter-and-fsm`](02-counter-and-fsm/) | Up/down counter and IDLE/UP/DOWN/READY controller with clock divider, debouncers, seven-segment display | Arty S7-50 |
| [`03-vending-machine`](03-vending-machine/) | Three-item vending machine with coin, filling and selling modes | Arty S7-50 |
| [`04-memory-controller`](04-memory-controller/) | Memory controllers for an SRAM model and a Block Memory Generator core | simulation |
| [`05-fifo-line-buffer`](05-fifo-line-buffer/) | Block-RAM FIFO and three-row line buffer | simulation |
| [`06-uart-loopback`](06-uart-loopback/) | UART receive, store in block RAM, transmit back | Arty S7-50 |
| [`07-axi-custom-ip`](07-axi-custom-ip/) | Memory controller as a custom IP in a Zynq block design | PYNQ-Z2 |
| [`08-sobel-filter`](08-sobel-filter/) | Sobel edge filter over line buffers, as a Zynq IP | PYNQ-Z2 |
| [`09-cnn-accelerator`](09-cnn-accelerator/) | MNIST CNN: Conv → ReLU → Conv → ReLU → MaxPool → FC → ArgMax | PYNQ-Z2 |

Each lab keeps its sources in `rtl/`, `tb/`, `vectors/`, `constraints/`, and, for the Zynq labs,
`ip/` and `bd/`.

## Simulation

```bash
python tools/run_sims.py            # every lab
python tools/run_sims.py 08 09      # selected labs
python tools/run_sims.py --vivado C:/Xilinx/Vivado/2022.1
python tools/run_sims.py --sim icarus
```

`run_sims.py` regenerates the test vectors, then compiles, elaborates and runs each testbench in
`build/sim/` and reports whether each testbench's own check passed. It uses Vivado's `xvlog` /
`xelab` / `xsim` when Vivado is installed and Icarus Verilog (`iverilog` / `vvp`, version 12)
otherwise. What each testbench checks:

| Lab | Testbench | Check |
|-----|-----------|-------|
| 01 | `tb_decoder_74ls138`, `tb_decoder_4to16` | Full truth tables, 64 input combinations each |
| 02 | `tb_top_counter` | 50 Hz divider period; counting, both limits and reset |
| 02 | `tb_top_fsm` | Divider period; every state transition, count checked on each 1 Hz tick |
| 03 | `tb_vending_machine` | Balance, stock limits and LEDs through filling, coin and selling sequences |
| 04 | `tb_memory_ctrlr` | All 192 packed output words |
| 04 | `tb_top_memory_wrapper` | All 256 running-sum entries in block RAM, for the course's data and for random data |
| 05 | `tb_fifo`, `tb_line_buffer` | Read order and full/empty flags; line buffer read-back |
| 06 | `tb_loopback` | 100 of 100 bytes echoed back in order over the UART |
| 06 | `tb_memory_control` | The controller alone at the board's 16,384-byte depth: LED after the last byte, every byte stored and returned in order |
| 07 | `tb_top_memory_ctrlr` | All 192 output words match the course's answer file |
| 08 | `tb_sobel_window` | 193 of 193 window outputs match \|Gx\| + \|Gy\| |
| 08 | `tb_line_buffer`, `tb_memory_ctrlr` | Read-back; all 10,000 output pixels written |
| 08 | `tb_top_memory_ctrlr` | All 10,000 output pixels match the reference edge image |
| 09 | `tb_maxpool_fc_argmax` | ArgMax picks the largest class sum |
| 09 | `tb_cnn_fsm` | 30 MNIST images with the trained weights; all 30 predictions and all 9,216 Conv2 result words match the golden model |

All eighteen testbenches pass in Icarus Verilog 12, which the repository runs on every push (the
badge above). They also pass in Vivado 2022.1's simulator.

### Test data

Stimulus is either synthetic with a computed expected result (the Sobel test image and its edge
image, the memory controller patterns), or taken from course-provided data: the lab 07 answer file,
the lab 06 test image, and for lab 09 the trained weights, 10,000 unlabeled MNIST images and the
reference outputs in `09-cnn-accelerator/reference/`. `tools/gen_vectors.py` writes the vectors of
labs 04, 08 and 09 from these; the other labs' testbenches compute their expected values
themselves or read the course files committed in their `vectors/`.

`tools/cnn_reference.py` is the golden model for lab 09. Implemented to the course specification,
it reproduces the course's reference logits exactly on all 10,000 images. Implemented the way the
RTL actually requantizes (see the [lab README](09-cnn-accelerator/README.md#golden-model)), its
predictions agree with the reference on 9,739 of them (97.39%); the simulation is checked against
that model.

### Block RAM models

The course projects use Block Memory Generator cores, whose `.xci` configurations are not part of
this repository. Instead, each lab's `rtl/` contains a small Verilog model of every memory with the
geometry and read latency the design expects, written in Vivado's RAM inference templates so the
same file simulates in xsim and synthesizes to block RAM.

## Hardware builds

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs <counter|fsm|vending|uart|cnn>
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs <axi|sobel|cnn>
```

`build_hw.tcl` runs synthesis, implementation and (for board designs) bitstream generation from the
lab sources. `build_bd.tcl` re-packages a Zynq lab's custom IP, imports its block design into a new
project, upgrades the Xilinx IP, and implements it through bitstream and an `.xsa`. Output goes to
`build/`.

| Design | Part | LUTs | FFs | BRAM tiles | DSP | Worst setup slack |
|--------|------|-----:|----:|-----------:|----:|------------------:|
| Counter | xc7s50 | 18 | 37 | 0 | 0 | +5.853 ns @ 100 MHz |
| FSM controller | xc7s50 | 30 | 65 | 0 | 0 | +5.529 ns @ 100 MHz |
| Vending machine | xc7s50 | 96 | 51 | 0 | 0 | +5.027 ns @ 100 MHz |
| UART loopback | xc7s50 | 104 | 118 | 4 | 0 | +8.908 ns @ 100 MHz |
| CNN core (out of context) | xc7z020 | 8,037 | 11,960 | 31.5 | 174 | +1.091 ns @ 100 MHz |
| CNN system (block design) | xc7z020 | 20,778 | 23,279 | 31.5 | 174 | +0.461 ns @ 100 MHz |
| AXI memory controller (block design) | xc7z020 | 6,281 | 7,554 | 5 | 0 | +3.539 ns @ 100 MHz |
| Sobel filter (block design) | xc7z020 | 6,525 | 7,514 | 11.5 | 0 | +0.588 ns @ 100 MHz |

The course's CNN core misses even 50 MHz (−6.456 ns: every dot product is one combinational block,
33 logic levels deep) and its Sobel filter misses 100 MHz. Both are pipelined here, and the CNN
system runs on the PS's 100 MHz clock without the clocking wizard of the course's block design. The
[CNN](09-cnn-accelerator/README.md#changes-from-the-course-design) and
[Sobel](08-sobel-filter/README.md#changes-from-the-course-design) READMEs describe how.

No design has been run on a board.

## Where this differs from the course designs

Faults in the course designs that this repository corrects, each covered by a testbench:

- `02` FSM: no undriven, unconstrained output port, which bitstream generation rejects.
- `04` block-RAM controller: every entry is written, and each read returns the entry being summed.
  The course's all-0x0001 data hides both faults, so the testbench also uses random data.
- `05` FIFO: works at any depth up to 128 (pointers zero-extended, wrapping at `FIFO_DEPTH − 1`).
- `06` loopback: all 15 block RAM address bits are driven, and the byte counters reach the board
  design's full 16,384 bytes.
- `08` Sobel: no latches in the adder, and a complete sensitivity list in `make_pixel`.
- `09` Conv1: each result is written at its own pixel; the course design writes it one pixel early,
  which shifts every feature map and changes predictions.

Every testbench checks its results, changes its stimulus clear of the clock edge the design samples,
and treats an unknown value as a failure.

## Requirements

Vivado 2022.1 (the block designs were saved with 2021.1 and are upgraded on import) and Python 3
with the packages in `requirements.txt`. The simulations alone need only Python, NumPy and Icarus
Verilog 12 or later (`apt install iverilog`, `brew install icarus-verilog`).

## License

Released under the [MIT License](LICENSE). The course-provided material listed above — the lab 06
modules and test image, the lab 07 answer file, and lab 09's weights, MNIST images and reference
outputs — remains the course's.
