# UART Loopback

A memory loopback for the Arty S7-50: a PC sends a 128×128 grayscale image over UART, the board
stores it in block RAM, and then sends it back so the PC can compare every pixel.

## Design

- `memory_control` is the part written for this assignment. On `rx_switch` it writes each byte
  received by the UART into block RAM from address 0 until `MEMORY_DEPTH` bytes have arrived, then
  lights the LED. On `tx_switch` it reads the memory back in the same order and hands each byte to
  the UART transmitter, accounting for the block RAM's one-cycle read latency.
- The UART receiver and transmitter, baud-rate generator, clock divider, metastability hardener,
  reset bridge and edge detectors are course-provided.

## Files

| Path | Description |
|------|-------------|
| `rtl/top_loopback.v` | Top level: clock divider, UART, memory controller, block RAM |
| `rtl/memory_control.v` | Receive / store / transmit controller |
| `rtl/uart_rx.v`, `rtl/uart_rx_ctl.v`, `rtl/uart_tx.v`, `rtl/uart_tx_ctl.v`, `rtl/uart_baud_gen.v` | UART (course-provided) |
| `rtl/clock_divider.v`, `rtl/meta_harden.v`, `rtl/reset_bridge.v`, `rtl/posedge_detector.v`, `rtl/negedge_detector.v` | Clocking, reset and synchronization helpers (course-provided) |
| `rtl/bram.v` | Behavioral model of the Block Memory Generator core (16,384-entry single port RAM, one-cycle read) |
| `tb/tb_loopback.v`, `tb/tester_loopback.v` | Testbench and a UART tester that sends the pattern and collects the echo |
| `tb/tb_memory_control.v` | Self-checking testbench of `memory_control` alone at the board's 16,384-byte depth |
| `vectors/testpattern.txt` | 4,096-byte test pattern as binary text (course-provided), read by the tester |
| `constraints/arty_s7.xdc` | Pin constraints |
| `host/uart_loopback.ipynb` | PC side for the board test: sends `host/images/testpattern.png`, reads it back and reports mismatched pixels |

## Verification

```bash
python tools/run_sims.py 06
```

- **`tb_loopback`** sends the first 100 bytes of the test pattern through the UART into the
  design, switches it to transmit, and checks that all 100 bytes come back in order.
- **`tb_memory_control`** drives the controller directly through the UART handshake signals, which
  makes the board design's full 16,384 bytes quick to simulate. It checks that the LED stays off
  until the last byte has arrived, that every byte is stored at its own address, and that transmit
  returns all 16,384 bytes in order.

The byte counters are one bit wider than the address, so they reach the 16,384-byte count that
lights the LED and enables transmit; `tb_memory_control` covers that depth, which the 100-byte UART
simulation cannot.

## Build and board test

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs uart
```

Program the board with `build/hw/uart/top_loopback.bit`, set `PORT` in
`host/uart_loopback.ipynb` to the board's serial port, and follow the steps in the notebook:
SW0 to receive, SW1 to transmit once LED2 lights.
