# AXI Custom IP

A Verilog memory controller packaged as a custom IP and connected to the Zynq processing system
(PS) through AXI, so software can load data, start the hardware, and read the result back.

## Design

- **`memory_ctrlr`** reads 256 16-bit words from `sram1` in two passes of 128 and packs them into
  192 32-bit words in `sram2`. It pairs each word with the one that arrived the cycle before, so the
  packing runs one word behind the addresses — `sram2[191 − i] = {sram1[2i − 1], sram1[2i]}` with a
  zero ahead of `sram1[0]`, then `sram1[127]`–`sram1[254]` into alternate halves of `sram2[0..127]`,
  and `sram1[255]` is not copied. That is the layout of the course's answer file, which the
  testbench checks against.
- **`top_memory_ctrlr`** wraps the controller and both memories. Port B of each memory belongs to
  the controller; port A is brought out so the PS can reach it through an AXI BRAM controller.
- **`csr`** is an AXI-Lite register IP: a rising edge on bit 0 of register 1 produces a one-cycle
  `start` pulse, and `done` is readable in bit 0 of register 0.

The block design (`bd/design_1.bd`) connects the Zynq PS through an AXI SmartConnect to two AXI
BRAM controllers (one per memory) and the `csr` IP, together with slice, concat and constant
cells, a processor reset block and an Integrated Logic Analyzer.

## Files

| Path | Description |
|------|-------------|
| `rtl/top_memory_ctrlr.v` | IP top level: controller plus both memories |
| `rtl/memory_ctrlr.v` | Two-pass read/pack/write controller |
| `rtl/sram1.v`, `rtl/sram2.v` | Behavioral models of the Block Memory Generator cores (256 × 16-bit and 256 × 32-bit true dual port, byte-wide write, one-cycle read) |
| `tb/tb_top_memory_ctrlr.v` | Self-checking testbench that plays the PS software |
| `vectors/init_memory.hex` | Values 1–256 written into `sram1` |
| `vectors/answer_memory.hex` | The course's expected `sram2` contents |
| `ip/csr_1.0/hdl/` | `csr` IP sources; `tools/build_bd.tcl` packages both IPs from their HDL |
| `bd/design_1.bd` | Block design |
| `reports/system_*.rpt` | Utilization and timing reports of the block-design build |

## Verification

```bash
python tools/run_sims.py 07
```

The testbench does what the PS software does on the board: it writes 1–256 into `sram1` through
port A, pulses `start`, waits for `done`, reads the 192 packed words back through port A and
compares every one with the course's answer file.

## Build

```bash
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs axi
```

The script re-packages `csr` and `top_memory_ctrlr` from their HDL, imports the block design into a
new project for the PYNQ-Z2 (`xc7z020clg400-1`), upgrades its Xilinx IP to the installed Vivado,
and implements it through bitstream and an `.xsa` hardware platform in `build/bd/axi/`.

Result with Vivado 2022.1: the design meets timing on the PS's 100 MHz clock (worst setup slack
+3.539 ns) and uses 6,281 LUTs, 7,554 flip-flops, 5 block RAM tiles and no DSP blocks, including the
Zynq PS support logic, the interconnect and the ILA.
