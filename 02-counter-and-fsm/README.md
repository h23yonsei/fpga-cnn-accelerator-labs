# Counter and FSM Controller

Two small sequential designs for the Arty S7-50 that share the same building blocks: a clock
divider from the 100 MHz board clock, D flip-flop debouncers, and a two-digit seven-segment
display.

## counter/ — 0 to 9 up/down counter

- `BTN0` counts up and stops at 9; `BTN1` counts down and stops at 0; `SW0` low resets to 0.
- `btn_debouncer` samples the button with two flip-flops at 50 Hz and emits a one-cycle pulse on
  the rising edge, so one press moves the count by exactly one.

| Path | Description |
|------|-------------|
| `rtl/top_counter.v` | Counter and seven-segment encoding |
| `rtl/clock_divider.v` | 100 MHz → 50 Hz |
| `rtl/btn_debouncer.v`, `rtl/dflipflop.v` | Two-flip-flop edge detector |
| `tb/tb_top_counter.v` | Self-checking testbench |
| `constraints/arty_s7.xdc` | Pin constraints |

## fsm/ — IDLE / UP / DOWN / READY controller

- `SW3` low holds IDLE and clears the count; with `SW3` high the controller moves to READY.
- `SW0` high selects UP, `SW1` high (with `SW0` low) selects DOWN, both low return to READY.
- The count changes once per second: +1 in UP up to 15, −1 in DOWN down to 0, held in READY.
  `LED[0]` lights in UP and `LED[1]` in DOWN.

| Path | Description |
|------|-------------|
| `rtl/top_fsm.v` | Top level |
| `rtl/fsm_ctrl.v` | State machine and 0–15 counter |
| `rtl/clock_divider.v` | 100 MHz → 50 Hz and 1 Hz |
| `rtl/sw_debouncer.v`, `rtl/dflipflop.v` | Switch debouncer (output changes after two agreeing samples) |
| `rtl/ssd_ctrl.v` | Two-digit seven-segment multiplexing |
| `tb/tb_top_fsm.v` | Self-checking testbench |
| `constraints/arty_s7.xdc` | Pin constraints |

## Verification

```bash
python tools/run_sims.py 02
```

Each testbench first runs the real 100 MHz clock until the divider's 50 Hz output has completed
a full 20 ms period and checks that period. It then drives the 50 Hz (and 1 Hz) clocks directly,
so the seconds-long button and switch sequences simulate quickly.

- **Counter:** 11 presses up stop at 9, 11 presses down stop at 0, 2 presses up give 2, `SW0` low
  resets — checked against both the internal count and the seven-segment pattern.
- **FSM:** on every 1 Hz tick the count is compared with what the state requires (+1 in UP up to
  15, −1 in DOWN down to 0, unchanged otherwise, 0 whenever `SW3` is low), while the switch
  sequence walks every transition, both boundaries and the reset, checking state and LEDs at each
  step.

## Build

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs counter
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs fsm
```

Synthesis, implementation and bitstream for the Arty S7-50 (`xc7s50csga324-1`); reports and the
`.bit` file are written to `build/hw/<lab>/`.
