# FIFO and Line Buffer

The two streaming structures a sliding-window image filter needs: a block-RAM FIFO, and a line
buffer that keeps three image rows available at once.

## Design

- **`fifo`**: a circular buffer in an 8 × 8-bit simple dual-port block RAM. Read and write pointers
  carry one extra bit, so `empty` is pointer equality and `full` is equal addresses with different
  top bits.
- **`line_buffer`**: three 8 × 8 FIFOs, one per image row. While `ready` is low, written samples
  fill FIFO 0, then FIFO 1, then FIFO 2, and `ready` rises once all three are full. While it is
  high, `rden_i` pops the three together, so `data_out` = {FIFO 2, FIFO 1, FIFO 0} delivers three
  rows in parallel to a 3×3 window, and `ready` falls once they are empty.

## Files

| Path | Description |
|------|-------------|
| `rtl/fifo.v` | FIFO (course-provided; pointer wrap changed, see below) |
| `rtl/line_buffer.v` | Three-row line buffer (port list from the course skeleton) |
| `rtl/fifo_mem.v` | Behavioral model of the Block Memory Generator core the FIFO instantiates (8 × 8-bit simple dual port, one-cycle read) |
| `tb/tb_fifo.v` | Self-checking FIFO testbench (depth 8), built on the course's |
| `tb/tb_line_buffer.v` | Self-checking line buffer testbench, built on the course's |

## Verification

```bash
python tools/run_sims.py 05
```

- **FIFO:** after reset it must be empty; after eight writes, full; the eight reads must return
  0–7 in order; and it must be empty again at the end.
- **Line buffer:** in each of two passes, 24 random samples are written with random gaps. Once
  `ready` rises, one more write must be refused, the three rows read back in parallel must equal
  what was written, and `ready` must fall without anything more being popped while `rden_i` stays
  high.

The pointers wrap after `FIFO_DEPTH − 1` instead of at the next power of two, so the FIFO works at
any depth up to the memory's eight entries: with `FIFO_DEPTH` overridden, the FIFO testbench passes
at every depth from 2 to 8.
