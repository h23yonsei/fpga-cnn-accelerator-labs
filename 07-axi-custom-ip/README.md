# AXI Custom IP

A Verilog memory controller packaged as a custom IP and connected to the Zynq processing system (PS)
through AXI, so software can load data, start the hardware, and read the result back. The controller
and its top level are course-provided; this lab adds the register IP's start and done logic, the
memory models, the block design and the testbenches, and completes the course's PS driver skeleton.

## Design

- **`memory_ctrlr`** reads 256 16-bit words from `sram1` in two passes of 128 and packs them into
  192 32-bit words in `sram2`. It pairs each word with the one that arrived the cycle before, so the
  packing runs one word behind the addresses — `sram2[191 − i] = {sram1[2i − 1], sram1[2i]}` with a
  zero ahead of `sram1[0]`, then `sram1[127]`–`sram1[254]` into alternate halves of `sram2[0..127]`,
  and `sram1[255]` is not copied. That is the layout of the course's answer file, which the
  testbench checks against.
- **`top_memory_ctrlr`** wraps the controller and both memories. Port B of each memory belongs to
  the controller; port A is brought out so the PS can reach it through an AXI BRAM controller.
- **`csr`** is an AXI4-Lite register IP: writing 1 to bit 0 of register 1 produces a one-cycle
  `start` pulse, after which the bit clears itself (the restore logic of week 9), so every write of
  1 starts the controller. `done` is readable in bit 0 of register 0.

The block design (`bd/design_1.bd`) connects the Zynq PS through an AXI SmartConnect to two AXI
BRAM controllers (one per memory) and the `csr` IP, together with slice, concat and constant
cells, a processor reset block and an Integrated Logic Analyzer.

## Files

| Path | Description |
|------|-------------|
| `rtl/top_memory_ctrlr.v` | IP top level: controller plus both memories (course-provided) |
| `rtl/memory_ctrlr.v` | Two-pass read/pack/write controller (course-provided) |
| `rtl/sram1.v`, `rtl/sram2.v` | Behavioral models of the Block Memory Generator cores (256 × 16-bit and 192 × 32-bit true dual port, byte-wide write, write-first, one-cycle read) |
| `tb/tb_top_memory_ctrlr.v` | Self-checking testbench that plays the PS software |
| `tb/tb_csr.v` | Self-checking testbench of the `csr` IP through its AXI4-Lite port |
| `vectors/init_memory.hex` | Values 1–256 written into `sram1` |
| `vectors/answer_memory.hex` | The course's expected `sram2` contents |
| `ip/csr_1.0/hdl/` | `csr` IP sources (Vivado's AXI4-Lite peripheral template with the start and done logic added); `tools/build_bd.tcl` packages both IPs from their HDL |
| `bd/design_1.bd` | Block design |
| `reports/system_*.rpt` | Utilization and timing reports of the block-design build |
| `host/pynq_driver.ipynb` | PS driver for the board test, built on the course's skeleton: loads the overlay, runs the controller and compares SRAM2 with the answer |
| `host/answer_memory.npy` | The course's expected `sram2` contents, as the driver reads them (course-provided) |

## Verification

```bash
python tools/run_sims.py 07
```

- **`tb_top_memory_ctrlr`** does what the PS software does on the board: it writes 1–256 into
  `sram1` through port A, pulses `start`, waits for `done`, reads the 192 packed words back through
  port A and compares every one with the course's answer file.
- **`tb_csr`** drives the `csr` IP through AXI4-Lite transactions, as the PS does: each write of 1
  to register 1 must produce exactly one `start` pulse, one cycle long, and read back as 0
  afterwards; a write of 0 must produce none, and register 0 must follow `done`.

`host/pynq_driver.ipynb` has not been run on a board, only against a Python stand-in for the overlay
that packs the words the way the answer file expects.

## Build and board test

```bash
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs axi
```

The script re-packages `csr` and `top_memory_ctrlr` from their HDL, imports the block design into a
new project for the PYNQ-Z2 (`xc7z020clg400-1`), upgrades its Xilinx IP to the installed Vivado, and
implements it through bitstream and an `.xsa` hardware platform in `build/bd/axi/`. It also writes
the bitstream and hardware handoff as `sram_controller.bit` and `sram_controller.hwh`, the names the
driver loads: copy both to the board with the files in `host/` and run the notebook.

Result with Vivado 2022.1: the design meets timing on the PS's 100 MHz clock (worst setup slack
+2.327 ns) and uses 6,301 LUTs, 7,554 flip-flops, 5 block RAM tiles and no DSP blocks, including the
Zynq PS support logic, the interconnect and the ILA.
