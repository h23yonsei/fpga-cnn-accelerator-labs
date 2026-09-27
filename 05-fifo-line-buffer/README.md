# FIFO and Line Buffer

The two streaming structures a sliding-window image filter needs: a block-RAM FIFO, and a line
buffer that keeps three image rows available at once.

## Design

- **`fifo`**: a circular buffer in a simple dual-port block RAM. Read and write pointers carry one
  extra bit, so `empty` is pointer equality and `full` is equal addresses with different top bits.
  The default depth is 102 — one row of the 102-pixel image used in `08-sobel-filter`.
- **`line_buffer`**: routes an incoming raster stream into three FIFOs, one per row, and raises
  `ready` once all three are full, so a 3×3 window can read the rows in parallel.

## Files

| Path | Description |
|------|-------------|
| `rtl/fifo.v` | FIFO |
| `rtl/line_buffer.v` | Three-row line buffer |
| `rtl/fifo_mem.v` | Behavioral model of the Block Memory Generator core the FIFO instantiates (128 × 8-bit simple dual port, one-cycle read) |
| `tb/tb_fifo.v` | Self-checking FIFO testbench (depth 8) |
| `tb/tb_line_buffer.v` | Self-checking line buffer testbench |

## Verification

```bash
python tools/run_sims.py 05
```

- **FIFO:** after reset it must be empty; after eight writes, full; the eight reads must return
  0–7 in order; and it must be empty again at the end.
- **Line buffer:** a stream is written through the buffer and read back, and the testbench compares
  what came out with what went in.

The pointers are zero-extended to the memory core's 7-bit address and wrap after
`FIFO_DEPTH − 1`, so the FIFO works at any depth up to 128: with `FIFO_DEPTH` overridden, the
testbench passes at every power of two from 2 to 128 and at 50, 100, 101, 102, 103 and 127.
