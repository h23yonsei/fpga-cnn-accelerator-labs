# Vending Machine

A three-item vending machine for the Arty S7-50, built as a set of small controllers around a
mode state machine.

## Specification

- Items cost 3, 5 and 7; coins are worth 1, 5 and 10.
- Stock per item stops at 5; the balance stops at 50 (a coin that would exceed it is refused).
- `SW3` turns the machine on and off; stock and balance are kept while it is off.
- `SW0` resets the machine: while it is high the machine stops, and once it is low again stock and
  balance start from 0.
- `SW1` high selects Coin Inserting, `SW2` high (with `SW1` low) Item Filling, both low Selling.
- `BTN1`–`BTN3` fill, insert or buy the corresponding item/coin in the current mode.
- `LED2`–`LED4` show the most recently filled item in Item Filling mode and out-of-stock items in
  Selling mode; `LED5` is on while the machine is operating.
- The seven-segment display shows the stock of the last filled item while filling and the balance in
  the other modes, and is dark while the machine is not operating.

## Files

| Path | Description |
|------|-------------|
| `rtl/vending_machine.v` | Top level (port list from the course skeleton) |
| `rtl/mode_ctrl.v` | IDLE / COIN / SELL / FILL state machine from the switches |
| `rtl/btn_ctrl.v` | Maps a debounced button press and the mode to an action, item and coin value |
| `rtl/action_ctrl.v` | Balance and stock updates with the stock and balance limits |
| `rtl/led_ctrl.v` | LED outputs |
| `rtl/ssd_ctrl.v` | Seven-segment display |
| `rtl/clock_divider.v`, `rtl/btn_debouncer.v`, `rtl/dflipflop.v` | 50 Hz clock and button debouncers (shared with `02-counter-and-fsm`) |
| `tb/tb_vending_machine.v` | Self-checking testbench |
| `constraints/arty_s7.xdc` | Pin constraints; the board clock and the 50 Hz clock divided from it |
| `reports/` | Utilization and timing reports of the build |

## Verification

```bash
python tools/run_sims.py 03
```

The testbench drives the 50 Hz clock directly and walks the specification: filling each item six
times (stock stops at 5), inserting coins to 48, refusing a 10 and a 5 that would exceed 50,
reaching 50 and refusing a 1 there, selling item 1 until it runs out, selling item 3 until the
balance runs out, refilling the balance, selling item 2 out and restocking item 1, then switching
the machine off and on (stock and balance kept, buttons ignored while off) and resetting it with
`SW0` (stock and balance 0 and buttons ignored while it is high, filling working again once it is
low), and last refusing to sell an item in stock that the balance does not cover. Balance, all three
stocks and `LED2`–`LED5` are checked after every step.

## Build

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs vending
```

Synthesis, implementation and bitstream for the Arty S7-50 (`xc7s50csga324-1`); reports and the
`.bit` file are written to `build/hw/vending/`. The reports in `reports/` come from Vivado 2022.1.
