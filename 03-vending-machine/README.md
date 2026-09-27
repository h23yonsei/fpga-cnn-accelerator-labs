# Vending Machine

A three-item vending machine for the Arty S7-50, built as a set of small controllers around a
mode state machine.

## Specification

- Items cost 3, 5 and 7; coins are worth 1, 5 and 10.
- Stock per item stops at 5; the balance stops at 50 (a coin that would exceed it is refused).
- `SW3` turns the machine on; turning it off clears stock and balance.
- `SW1` high selects Coin Inserting, `SW2` high (with `SW1` low) Item Filling, both low Selling.
- `BTN1`–`BTN3` fill, insert or buy the corresponding item/coin in the current mode.
- `LED2`–`LED4` show the most recently filled item in Item Filling mode and out-of-stock items in
  Selling mode; `LED5` is on while the machine is on.
- The seven-segment display shows the stock of the last filled item while filling and the balance
  otherwise.

## Files

| Path | Description |
|------|-------------|
| `rtl/vending_machine.v` | Top level (port list from the course skeleton) |
| `rtl/mode_ctrl.v` | IDLE / COIN / SELL / FILL state machine from the switches |
| `rtl/btn_ctrl.v` | Maps a debounced button press and the mode to a task, item and coin value |
| `rtl/action_ctrl.v` | Balance and stock updates with the stock and balance limits |
| `rtl/led_ctrl.v` | LED outputs |
| `rtl/ssd_ctrl.v` | Seven-segment display |
| `rtl/clock_divider.v`, `rtl/btn_debouncer.v`, `rtl/dflipflop.v` | 50 Hz clock and button debouncers (shared with `02-counter-and-fsm`) |
| `tb/tb_vending_machine.v` | Self-checking testbench |
| `constraints/arty_s7.xdc` | Pin constraints |

## Verification

```bash
python tools/run_sims.py 03
```

The testbench drives the 50 Hz clock directly and walks the specification: filling each item six
times (stock stops at 5), inserting coins to 48, refusing a 10 and a 5 that would exceed 50,
reaching 50, selling item 1 until it runs out, selling item 3 until the balance runs out,
refilling the balance and selling item 2 out, then switching the machine off and on. Balance,
all three stocks and `LED2`–`LED5` are checked after every step.

## Build

```bash
vivado -mode batch -nojournal -source tools/build_hw.tcl -tclargs vending
```
