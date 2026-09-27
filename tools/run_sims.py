#!/usr/bin/env python3
"""
Run every testbench in this repository with Vivado's simulator or with Icarus Verilog.

    python tools/run_sims.py                     # all labs
    python tools/run_sims.py 08 09               # only labs whose directory starts with 08 / 09
    python tools/run_sims.py --vivado C:/Xilinx/Vivado/2022.1
    python tools/run_sims.py --sim icarus        # Icarus Verilog instead of Vivado

With Vivado, each lab is compiled from its rtl/ and tb/ directories with `xvlog`, elaborated with
`xelab` and run with `xsim`; with Icarus, each testbench is compiled with `iverilog` and run with
`vvp`. By default Vivado is used when it can be found and Icarus Verilog otherwise. Everything runs
in build/sim/<lab>/ (git-ignored). The lab's vectors/ directory is copied there first, so the
testbenches' `VECTOR_DIR` paths resolve. Stimulus comes from tools/gen_vectors.py, which this
script calls before anything else.

The Block Memory Generator cores the labs instantiate are committed as behavioral RTL in each
lab's rtl/ directory, so nothing here is generated at simulation time.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BUILD = REPO / "build" / "sim"

# ---------------------------------------------------------------------------
# lab definitions
# ---------------------------------------------------------------------------
# Each testbench maps to a check:
#   ("check", regex)  the testbench's own self-check reported success
#   "uart_echo"       every byte the tester sent came back, in order
PASS_MSG = ("check", r"PASS: memory comparison succeeded")

LABS = [
    dict(dir="01-decoder-74ls138",
         tbs={"tb/tb_decoder_74ls138.v": ("check", r"PASS: 74LS138 truth table"),
              "tb/tb_decoder_4to16.v": ("check", r"PASS: 4-to-16 decoder")}, runtime="all"),
    dict(dir="02-counter-and-fsm/counter",
         tbs={"tb/tb_top_counter.v": ("check", r"PASS: counter and clock divider")}, runtime="all"),
    dict(dir="02-counter-and-fsm/fsm",
         tbs={"tb/tb_top_fsm.v": ("check", r"PASS: FSM controller")}, runtime="all"),
    dict(dir="03-vending-machine",
         tbs={"tb/tb_vending_machine.v": ("check", r"PASS: vending machine")}, runtime="all"),
    dict(dir="04-memory-controller/sram",
         tbs={"tb/tb_memory_ctrlr.v": PASS_MSG}, runtime="all"),
    dict(dir="04-memory-controller/bram",
         tbs={"tb/tb_top_memory_wrapper.v": PASS_MSG}, runtime="all"),
    dict(dir="05-fifo-line-buffer",
         tbs={"tb/tb_fifo.v": ("check", r"PASS: FIFO returned"), "tb/tb_line_buffer.v": PASS_MSG}, runtime="200ms"),
    dict(dir="06-uart-loopback", extra=["tb/tester_loopback.v"], copy=["vectors/testpattern.txt"],
         tbs={"tb/tb_loopback.v": "uart_echo",
              "tb/tb_memory_control.v": ("check", r"PASS: memory_control stored and returned all 16384")},
         runtime="200ms"),
    dict(dir="07-axi-custom-ip",
         tbs={"tb/tb_top_memory_ctrlr.v": ("check", r"PASS: sram2 matches the course answer")}, runtime="all"),
    dict(dir="08-sobel-filter",
         tbs={"tb/tb_sobel_window.v": ("check", r"PASS: Sobel window matched the reference"),
              "tb/tb_line_buffer.v": PASS_MSG,
              "tb/tb_memory_ctrlr.v": ("check", r"PASS: controller wrote all 10000 output pixels"),
              "tb/tb_top_memory_ctrlr.v": ("check", r"PASS: all 10000 output pixels match")},
         runtime="200ms"),
    dict(dir="09-cnn-accelerator",
         tbs={"tb/tb_maxpool_fc_argmax.v": ("check", r"PASS: MaxPool -> FC -> ArgMax"),
              "tb/tb_cnn_fsm.v": ("check", r"PASS: CNN predictions match the golden model")},
         runtime="6s"),
]


# ---------------------------------------------------------------------------
def find_vivado(explicit: str | None) -> Path | None:
    for cand in [explicit, os.environ.get("XILINX_VIVADO")]:
        if cand and (Path(cand) / "bin").exists():
            return Path(cand) / "bin"
    exe = shutil.which("xvlog") or shutil.which("xvlog.bat")
    return Path(exe).parent if exe else None


def run(cmd: list[str], cwd: Path, log: Path, timeout: int = 3600) -> int:
    with log.open("w") as fh:
        try:
            return subprocess.run(cmd, cwd=cwd, stdout=fh, stderr=subprocess.STDOUT,
                                  timeout=timeout, shell=(os.name == "nt")).returncode
        except subprocess.TimeoutExpired:
            fh.write("\nWALL-CLOCK TIMEOUT\n")
            return -1


def tool(bindir: Path, name: str) -> str:
    exe = bindir / (name + ".bat") if os.name == "nt" else bindir / name
    return str(exe)


def errors(log: Path) -> list[str]:
    return [l.strip() for l in log.read_text(errors="ignore").splitlines() if l.startswith("ERROR")]


def uart_echo(sim_log: str) -> tuple[bool, str]:
    """Every byte transmitted to the loopback must come back, in order."""
    sent = [b for b in re.findall(r"Tester transmit ([0-9a-fA-F]{2})", sim_log) if b != "00"]
    got = re.findall(r"Tester received ([0-9a-fA-F]{2})", sim_log)
    n = sum(1 for a, b in zip(sent, got) if a == b)
    return (len(sent) > 0 and n == len(sent) == len(got)), f"{n}/{len(sent)} bytes echoed back in order"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("labs", nargs="*", help="directory prefixes to run (default: all)")
    ap.add_argument("--vivado", help="Vivado install directory (contains bin/xvlog)")
    ap.add_argument("--sim", choices=["xsim", "icarus"],
                    help="simulator (default: xsim if Vivado is found, otherwise Icarus Verilog)")
    args = ap.parse_args()
    bindir = find_vivado(args.vivado)
    sim = args.sim or ("xsim" if bindir else "icarus")
    if sim == "xsim" and not bindir:
        sys.exit("xvlog not found: pass --vivado <install dir> or put Vivado's bin/ on PATH")
    if sim == "icarus" and not (shutil.which("iverilog") and shutil.which("vvp")):
        sys.exit("neither Vivado nor Icarus Verilog found: install one, or pass --vivado <install dir>")
    print(f"Simulator: {'Vivado xsim' if sim == 'xsim' else 'Icarus Verilog'}")

    subprocess.run([sys.executable, str(REPO / "tools/gen_vectors.py")], check=True, stdout=subprocess.DEVNULL)

    results = []
    for lab in LABS:
        if args.labs and not any(lab["dir"].startswith(p) for p in args.labs):
            continue
        pdir = REPO / lab["dir"]
        work = BUILD / lab["dir"].replace("/", "_")
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True)
        if (pdir / "vectors").is_dir():
            shutil.copytree(pdir / "vectors", work / "vectors")
        for f in lab.get("copy", []):
            shutil.copy(pdir / f, work / Path(f).name)
        files = ([str(p) for p in sorted((pdir / "rtl").glob("*.v"))]
                 + [str(pdir / f) for f in lab.get("extra", [])]
                 + [str(pdir / tb) for tb in lab["tbs"]])

        print(f"\n== {lab['dir']}")
        if sim == "xsim":
            run([tool(bindir, "xvlog")] + files, work, work / "xvlog.log")
            if errors(work / "xvlog.log"):
                for tb in lab["tbs"]:
                    results.append((lab["dir"], Path(tb).stem, "FAIL", errors(work / "xvlog.log")[0][:100]))
                print("   compile failed:", errors(work / "xvlog.log")[0])
                continue
        for tb, expect in lab["tbs"].items():
            top = re.search(r"(?m)^\s*module\s+(\w+)", (pdir / tb).read_text(errors="ignore")).group(1)
            if sim == "xsim":
                run([tool(bindir, "xelab"), top, "-s", f"snap_{top}", "-timescale", "1ns/1ps"],
                    work, work / f"xelab_{top}.log")
                if errors(work / f"xelab_{top}.log"):
                    results.append((lab["dir"], top, "FAIL", errors(work / f"xelab_{top}.log")[0][:100]))
                    continue
                (work / f"run_{top}.tcl").write_text(f"run {lab['runtime']}\nquit\n")
                run([tool(bindir, "xsim"), f"snap_{top}", "-tclbatch", f"run_{top}.tcl", "-log", f"sim_{top}.log"],
                    work, work / f"xsim_{top}.out")
            else:
                # every testbench ends with $finish, so vvp runs to completion without a runtime limit
                if run(["iverilog", "-g2012", "-s", top, "-o", f"{top}.vvp"] + files,
                       work, work / f"iverilog_{top}.log"):
                    note = (work / f"iverilog_{top}.log").read_text(errors="ignore").strip().splitlines()
                    results.append((lab["dir"], top, "FAIL", (note or ["compile failed"])[0][:100]))
                    print(f"   {top:24s} FAIL  compile failed")
                    continue
                run(["vvp", "-n", f"{top}.vvp"], work, work / f"sim_{top}.log")
            sim_log = work / f"sim_{top}.log"
            log = sim_log.read_text(errors="ignore") if sim_log.exists() else ""
            clean = not re.search(r"(?m)^(ERROR|FATAL|Error:)", log)
            if expect == "uart_echo":
                ok, note = uart_echo(log)
            else:
                _, rx = expect
                ok = re.search(rx, log) is not None and clean
                note = "self-check passed" if ok else "self-check FAILED"
            results.append((lab["dir"], top, "PASS" if ok else "FAIL", note))
            print(f"   {top:24s} {'PASS' if ok else 'FAIL'}  {note}")

    print("\n" + "=" * 78)
    for d, top, status, note in results:
        print(f"{status:4s}  {d:32s} {top:24s} {note}")
    sys.exit(0 if all(r[2] == "PASS" for r in results) else 1)


if __name__ == "__main__":
    main()
