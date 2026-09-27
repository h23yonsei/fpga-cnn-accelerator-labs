# Memory Controllers

Two controllers that move data between memories, written against the interfaces of an SRAM model
and of a Vivado Block Memory Generator core.

## sram/ — packing SRAM1 into SRAM2

`memory_ctrlr` copies a 256 × 16-bit SRAM into a 192 × 32-bit SRAM in two phases:

- **Phase 1:** words 0–127 of SRAM1 are packed in pairs,
  `SRAM2[191 − i] = {SRAM1[2i], SRAM1[2i+1]}`.
- **Phase 2:** words 128–255 are placed from address 0 upward, even words in the low half
  (`{16'h0, SRAM1[c]}`), odd words in the high half (`{SRAM1[c], 16'h0}`).

| Path | Description |
|------|-------------|
| `rtl/memory_ctrlr.v` | Controller state machine |
| `rtl/sram_model.v` | Behavioral SRAM (1 ns write delay, combinational read) |
| `rtl/top_memory_ctrlr.v` | Controller and the two SRAMs |
| `tb/tb_memory_ctrlr.v` | Self-checking testbench |
| `vectors/` | Random SRAM1 contents and the expected SRAM2 image |

## bram/ — running sum in a block RAM

`memory_ctrlr` walks a 256 × 16-bit simple dual-port block RAM that starts with the contents of
`initialize_memory.coe`, replacing each entry with the running sum of the entries so far.

| Path | Description |
|------|-------------|
| `rtl/memory_ctrlr.v` | Controller state machine |
| `rtl/top_memory_wrapper.v` | Controller and block RAM; exposes port B for read-back once `done` |
| `rtl/bram.v` | Behavioral model of the Block Memory Generator core (simple dual port, primitive output register, initialized from the `.coe` data) |
| `tb/tb_top_memory_wrapper.v` | Self-checking testbench: the course's data and random data, side by side |
| `vectors/` | `initialize_memory.coe` (course-provided), its `$readmemh` form, random data, and the expected sums of both |

The course project uses a Block Memory Generator core, whose `.xci` is not part of this repository;
the behavioral model reproduces the configuration the lab called for (simple dual port RAM with the
primitive output register, so a two-cycle read latency).

## Verification

```bash
python tools/run_sims.py 04
```

`tools/gen_vectors.py` writes the vectors. The expected results are computed from the controllers'
transfer functions — the two-phase pack and the running sum. Both testbenches read every output
word back and report `PASS: memory comparison succeeded`.

The block-RAM controller keeps port B enabled for the whole run and addresses it with the cursor
register itself, so every read returns the entry being summed. The course's `initialize_memory.coe`
is 0x0001 in every entry, which cannot tell a correct running sum from one built on stale reads, so
the testbench also runs a second RAM seeded with random 16-bit values, whose sums wrap around. It
drives its inputs on the falling clock edge, clear of the edge the RAM samples.
