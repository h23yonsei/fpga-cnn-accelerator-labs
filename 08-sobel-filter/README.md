# Sobel Edge Filter

A hardware Sobel edge detector packaged as a custom IP for the Zynq. The PS loads an image into
block RAM, starts the filter, and reads back the edge image.

## Design

```text
bram1 (102×102 image) → line buffer (3 rows) → 3×3 window → |Gx| + |Gy| → bram2 (100×100 edges)
```

- **`memory_ctrlr`** reads the input image from `bram1` as 100 three-row bands, each starting one
  row below the last, feeds each band through the line buffer, and writes one output pixel per
  window position into `bram2` — 10,000 in total.
- **`line_buffer`** holds three 102-pixel rows in FIFOs (the structure from
  `05-fifo-line-buffer`), so the window sees three rows at once while pixels arrive one per cycle.
- **`sobel_window`** shifts the rows into a 3×3 window and computes the edge strength
  S = |Gx| + |Gy|, saturated to 255: `pixel_sign_ext` widens the pixels to signed values,
  `signed_mult` and `adder9` form the two gradients, `abs16` takes their magnitudes, and
  `make_pixel` adds and saturates. The two gradient sums are registered, so `edge_out` appears one
  cycle after its window, flagged by `result_valid` (see
  [below](#changes-from-the-course-submission)).
- **`csr`** is the AXI4-Lite control/status register IP from `07-axi-custom-ip`: writing 1 to bit 0
  of register 1 starts the filter (the bit then clears itself), and `done` is readable in bit 0 of
  register 0.

The block design (`bd/design_1.bd`) follows the same pattern as lab 07: the Zynq PS, an AXI
SmartConnect, the AXI BRAM controllers `IMEM_ctrlr` and `OMEM_ctrlr` (one per image memory) and the
`csr` IP at the addresses Assignment 3 assigns, and the filter IP, together with slice, concat and
constant cells, a processor reset block and an Integrated Logic Analyzer. As the assignment asks,
SW0 resets the PL through the processor reset block, and `done` also lights LD0.

## Files

| Path | Description |
|------|-------------|
| `rtl/top_memory_ctrlr.v` | IP top level: controller, filter and both image memories |
| `rtl/memory_ctrlr.v` | Read / filter / write controller |
| `rtl/line_buffer.v`, `rtl/fifo.v` | Three-row line buffer on the course's FIFO, as in lab 05 |
| `rtl/sobel_window.v` | 3×3 window and edge-strength datapath |
| `rtl/pixel_sign_ext.v`, `rtl/signed_mult.v`, `rtl/adder9.v`, `rtl/abs16.v`, `rtl/make_pixel.v` | Datapath stages |
| `rtl/bram1.v`, `rtl/bram2.v`, `rtl/fifo_mem.v` | Behavioral models of the Block Memory Generator cores (10,404 × 8-bit and 10,000 × 8-bit true dual port, write-first; 128 × 8-bit simple dual port) |
| `tb/tb_top_memory_ctrlr.v` | Full filter against a reference edge image |
| `tb/tb_memory_ctrlr.v` | Controller write count |
| `tb/tb_line_buffer.v` | Line buffer read-back, built on the course's lab 05 testbench |
| `tb/tb_sobel_window.v` | Edge-strength datapath against a model computed in the testbench |
| `vectors/fake_image.hex` | Synthetic 102×102 test image (nested rectangles and a diagonal) |
| `vectors/sobel_expected.hex` | Its \|Gx\| + \|Gy\| reference, computed in Python |
| `ip/csr_1.0/hdl/` | Register IP sources (the `csr` IP of lab 07) |
| `bd/design_1.bd` | Block design |
| `constraints/pynq_z2.xdc` | PYNQ-Z2 constraints (course-provided) |
| `reports/system_*.rpt` | Utilization and timing reports of the block-design build |
| `host/assignment3.ipynb` | PS-side test for the board: loads the overlay, filters `Penguin.jpg` and compares the result with a SciPy reference (course-provided, saved outputs cleared) |
| `host/Penguin.jpg` | Test image the notebook resizes to 102×102 (course-provided) |

## Verification

```bash
python tools/run_sims.py 08
```

`tools/gen_vectors.py` generates the test image and its reference edge image.

| Testbench | Check |
|-----------|-------|
| `tb_sobel_window` | 200 random pixel columns; every one of the 193 valid outputs matches S = \|Gx\| + \|Gy\| computed over the same window |
| `tb_line_buffer` | The stream read back equals the stream written |
| `tb_memory_ctrlr` | The controller writes all 10,000 output pixels |
| `tb_top_memory_ctrlr` | All 10,000 output pixels, read back through port A, match the reference |

## Build and board test

```bash
vivado -mode batch -nojournal -source tools/build_bd.tcl -tclargs sobel
```

The script re-packages both IPs from their HDL, imports the block design into a new project for the
PYNQ-Z2 (`xc7z020clg400-1`), upgrades its Xilinx IP, and implements it through bitstream and an
`.xsa` hardware platform in `build/bd/sobel/`. It also writes the bitstream and hardware handoff as
`sobel_ps.bit` and `sobel_ps.hwh`, the names the course's notebook loads: copy both to the board
with the files in `host/`, set SW0 on (it is the PL's active-low reset) and run the notebook. In the
built design the `csr` IP sits at 0x40010000 rather than at its saved 0x43C00000 (see
`tools/build_bd.tcl`); the notebook finds it by name.

Result with Vivado 2022.1: the design meets timing on the PS's 100 MHz clock (worst setup slack
+1.224 ns) and uses 6,524 LUTs, 7,514 flip-flops, 11.5 block RAM tiles and no DSP blocks.

### Changes from the course submission

The design submitted for the course misses 100 MHz: window, multiplies, adder trees, absolute
values, saturation and the `bram2` write form one 13.6 ns path (−4.5 ns). The design here meets it:

- **`sobel_window` registers the gradient sums.** The longest stage is 7.8 ns, from the registered
  sums through the absolute values and saturation into `bram2`
  (`reports/system_timing_summary_routed.rpt`). `memory_ctrlr` delays the `bram2` write enable and
  address by the same cycle and raises `done` after the last write; row pacing is unchanged.
- **`adder9` is purely combinational.** The submitted version reset its sums inside combinational
  logic, which inferred latches in the pixel path.
- **`make_pixel` is a continuous assignment,** with no sensitivity list to leave incomplete, so
  simulation never samples a stale sum.
