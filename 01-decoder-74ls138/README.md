# 74LS138 Decoder

A 74LS138 3-to-8 decoder/demultiplexer described twice — once from gates, once behaviorally —
and then two of them combined into a 4-to-16 decoder.

## Design

- Active-low outputs: exactly one output `Y[{C,B,A}]` is low, and only while the chip is enabled
  (`G1 = 1`, `G2A = G2B = 0`); otherwise all outputs are high.
- `decoder_74ls138_gates` builds that from AND/NOT gates; `decoder_74ls138` expresses it with
  `assign`.
- The 4-to-16 decoder feeds a fourth input `D` to `G1` of one chip and `~D` to the other, so only
  one half is enabled at a time.

## Files

| Path | Description |
|------|-------------|
| `rtl/decoder_74ls138_gates.v` | Gate-level decoder |
| `rtl/decoder_74ls138.v` | Behavioral decoder |
| `tb/tb_decoder_74ls138.v` | Both decoders against the truth table: every select code under all 8 enable combinations |
| `tb/tb_decoder_4to16.v` | Two gate-level chips as a 4-to-16 decoder: all 16 codes under all 4 `G2A`/`G2B` combinations |

## Verification

```bash
python tools/run_sims.py 01
```

Both testbenches compute the expected outputs from the truth table and report
`PASS: 74LS138 truth table, 64 vectors` and `PASS: 4-to-16 decoder, 64 vectors`.
