# Sobel Edge Filter

A hardware Sobel edge detector packaged as a custom IP for the Zynq. The PS loads an image into
block RAM, starts the filter, and reads back the edge image.

## Design

```text
bram1 (102×102 padded image) → line buffer (3 rows) → 3×3 window → |Gx| + |Gy| → bram2 (100×100 edges)
```

- **`memory_ctrlr`** reads the 10,404-pixel padded input from `bram1` in raster order, feeds the
  line buffer, and writes one output pixel per window position into `bram2` — 10,000 in total.
- **`line_buffer`** holds three 102-pixel rows in FIFOs (the structure from
  `05-fifo-line-buffer`), so the window sees three rows at once while pixels arrive one per cycle.
- **`sobel_window`** shifts the rows into a 3×3 window and computes the edge strength
  S = |Gx| + |Gy|, saturated to 255: `pixel_sign_ext` widens the pixels to signed values,
  `signed_mult` and `adder9` form the two gradients, `abs16` takes their magnitudes, and
  `make_pixel` adds and saturates. The two gradient sums are registered, so `edge_out` appears one
  cycle after its window, flagged by `result_valid` (see [Build](#build)).
- **`csr`** is the AXI-Lite control/status register IP from `07-axi-custom-ip`: a rising edge on bit
  0 of register 1 starts the filter, and `done` is readable in bit 0 of register 0.

The block design (`bd/design_1.bd`) follows the same pattern as lab 07: the Zynq PS, an AXI
SmartConnect, one AXI BRAM controller per image memory, the `csr` IP and the filter IP.

## Files

| Path | Description |
|------|-------------|
| `rtl/top_memory_ctrlr.v` | IP top level: controller, filter and both image memories |
| `rtl/memory_ctrlr.v` | Read / filter / write controller |
| `rtl/line_buffer.v`, `rtl/fifo.v` | Three-row line buffer |
| `rtl/sobel_window.v` | 3×3 window and edge-strength datapath |
| `rtl/pixel_sign_ext.v`, `rtl/signed_mult.v`, `rtl/adder9.v`, `rtl/abs16.v`, `rtl/make_pixel.v` | Datapath stages |
| `rtl/bram1.v`, `rtl/bram2.v`, `rtl/fifo_mem.v` | Behavioral models of the Block Memory Generator cores (16,384 × 8-bit true dual port; 128 × 8-bit simple dual port) |
| `tb/tb_top_memory_ctrlr.v` | Full filter against a reference edge image |
| `tb/tb_memory_ctrlr.v` | Controller write count |
| `tb/tb_line_buffer.v` | Line buffer read-back |
| `tb/tb_sobel_window.v` | Edge-strength datapath against a model computed in the testbench |
| `vectors/fake_image.hex` | Synthetic 102×102 test image (nested rectangles and a diagonal) |
| `vectors/sobel_expected.hex` | Its \|Gx\| + \|Gy\| reference, computed in Python |
| `ip/csr_1.0/hdl/` | Register IP sources (the `csr` IP of lab 07) |
| `bd/design_1.bd`, `constraints/pynq_z2.xdc` | Block design and PYNQ-Z2 constraints |
| `reports/system_*.rpt` | Utilization and timing reports of the block-design build |

## Verification

```bash
python tools/run_sims.py 08
```

`tools/gen_vectors.py` generates the test image and its reference edge image.

| Testbench | Check |
|-----------|-------|
| `tb_sobel_window` | 200 random pixel columns; every one of the 193 valid outputs matches \|S\| computed over the same window |
| `tb_line_buffer` | The stream read back equals the stream written |
| `tb_memory_ctrlr` | The controller writes all 10,000 output pixels |
| `tb_top_memory_ctrlr` | All 10,000 output pixels, read back through port A, match the reference |

## Build

```bash
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs sobel
```

The script re-packages both IPs from their HDL, imports the block design into a new project for the
PYNQ-Z2 (`xc7z020clg400-1`), upgrades its Xilinx IP, and implements it through bitstream and an
`.xsa` hardware platform in `build/bd/sobel/`.

Result with Vivado 2022.1: the design meets timing on the PS's 100 MHz clock (worst setup slack
+0.588 ns) and uses 6,525 LUTs, 7,514 flip-flops, 11.5 block RAM tiles and no DSP blocks.

### Changes from the course design

The course design misses 100 MHz: window, multiplies, adder trees, absolute values, saturation and
the `bram2` write form one 13.6 ns path (−4.5 ns). The design here meets it:

- **`sobel_window` registers the gradient sums.** The longest stage is 8.3 ns, from the registered
  sums through the absolute values and saturation into `bram2`
  (`reports/system_timing_summary_routed.rpt`). `memory_ctrlr` delays the `bram2` write enable and
  address by the same cycle and raises `done` after the last write; row pacing is unchanged.
- **`adder9` is purely combinational.** The course version reset its sums inside combinational
  logic, which inferred latches in the pixel path.
- **`make_pixel` uses `@(*)`,** so simulation never samples a stale sum.
