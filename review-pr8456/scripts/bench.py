#!/usr/bin/env python3
"""Build baseline and PR models of a design at several thread counts, print
DFG sharing statistics and code size, then time interleaved executions.

usage: BASE_ROOT=<tree> PR_ROOT=<tree> bench.py <tag> <src.v> <reps> <threads,...> [verilator flags]
e.g.:  python3 ../designs/genbench.py 64 48 16000 512 > wide.v
       bench.py wide wide.v 9 1,2,4,6,8
       bench.py wide_nocomb wide.v 9 1,4,6 -fno-combine

Models are cached per <tag>; use a new tag after changing the design or flags.
"""
import os
import re
import statistics
import subprocess
import sys
import time

ROOTS = {"base": os.environ["BASE_ROOT"], "pr": os.environ["PR_ROOT"]}
OUT = os.environ.get("OUT", os.path.join(os.getcwd(), "out"))
tag, src, reps, threads = sys.argv[1], os.path.abspath(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
extra = sys.argv[5:]
threads = [int(t) for t in threads.split(",")]
variants = ["base", "pr"]


def stat(path, name):
    try:
        with open(path, encoding="utf8") as fh:
            m = re.search(re.escape(name) + r"\s+([\d.]+)\s*$", fh.read(), re.M)
        return m.group(1) if m else "0"
    except FileNotFoundError:
        return "-"


def text_size(exe):
    # GNU binutils first, then macOS
    out = subprocess.run(["size", "-A", exe], capture_output=True, text=True).stdout
    m = re.search(r"^\.text\s+(\d+)", out, re.M)
    if not m:
        out = subprocess.run(["size", "-m", exe], capture_output=True, text=True).stdout
        m = re.search(r"Section __text: (\d+)", out)
    return int(m.group(1)) if m else -1


objs = {}
for t in threads:
    for v in variants:
        od = os.path.join(OUT, f"bench_{tag}_{v}_t{t}")
        objs[(v, t)] = od
        if os.path.exists(os.path.join(od, "Vtop")):
            continue
        subprocess.run(["rm", "-rf", od], check=True)
        os.makedirs(od)
        env = dict(os.environ, VERILATOR_ROOT=ROOTS[v])
        cmd = [os.path.join(ROOTS[v], "bin", "verilator"), "--binary", "--stats", "-Mdir", od,
               "--prefix", "Vtop", "-j", "8", "--threads", str(t)] + extra + [src]
        r = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if r.returncode:
            print(r.stdout[-2000:], r.stderr[-2000:])
            sys.exit(f"build failed {v} t{t}")

print(f"{'cfg':>8} {'reused':>7} {'combined':>9} {'Vdfg-mem':>9} {'.text':>9}  hash")
for t in threads:
    for v in variants:
        od = objs[(v, t)]
        st = os.path.join(od, "Vtop__stats.txt")
        vdfg = 0
        for f in os.listdir(od):
            if f.endswith(".h"):
                with open(os.path.join(od, f), encoding="utf8") as fh:
                    vdfg += fh.read().count("__Vdfg")
        out = subprocess.run([os.path.join(od, "Vtop")], capture_output=True, text=True,
                             cwd=od).stdout
        h = re.search(r"hash (\w+)", out)
        print(f"{v:>4} t{t:<2} {stat(st, 'temporary declarations reused'):>7} "
              f"{stat(st, 'Optimizations, Combined CFuncs'):>9} {vdfg:>9} "
              f"{text_size(os.path.join(od, 'Vtop')):>9}  {h.group(1) if h else 'NOHASH'}")

times = {k: [] for k in objs}
for rep in range(reps):
    for t in threads:
        # Alternate the order of variants between repetitions
        for v in (variants if rep % 2 == 0 else variants[::-1]):
            od = objs[(v, t)]
            t0 = time.perf_counter()
            subprocess.run([os.path.join(od, "Vtop")], capture_output=True, cwd=od, check=True)
            times[(v, t)].append(time.perf_counter() - t0)

print(f"\n{'threads':>7} {'base med(s)':>12} {'pr med(s)':>10} {'pr/base':>8}   base min / pr min")
for t in threads:
    b, p = times[("base", t)], times[("pr", t)]
    mb, mp = statistics.median(b), statistics.median(p)
    print(f"{t:>7} {mb:>12.3f} {mp:>10.3f} {mp / mb:>8.3f}   {min(b):.3f} / {min(p):.3f}")
