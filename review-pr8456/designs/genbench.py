#!/usr/bin/env python3
"""Generate the benchmark wsnyder suggested on the PR: one submodule with
significant logic, instantiated many times, with little cross-instance
communication. Each instance runs its own LFSR-driven datapath with many
common subexpressions (so DFG introduces temporaries) spread across several
always blocks (so --threads can split an instance across MTasks)."""
import random
import sys

n_inst = int(sys.argv[1]) if len(sys.argv) > 1 else 32
n_stages = int(sys.argv[2]) if len(sys.argv) > 2 else 24
cycles = int(sys.argv[3]) if len(sys.argv) > 3 else 200000
W = int(sys.argv[4]) if len(sys.argv) > 4 else 64
rng = random.Random(1234)

ops = ["+", "-", "^", "&", "|"]
L = []
w = L.append
w("module core (input clk, input [63:0] seed, input [%d:0] nbr, output logic [%d:0] out);" % (W-1, W-1))
w("  /* verilator no_inline_module */")
w("  logic [63:0] lfsr = 64'h1;")
w("  logic [%d:0] st [%d];" % (W-1, n_stages))
w("  initial for (int i = 0; i < %d; ++i) st[i] = %d'(i) * %d'h9e3779b97f4a7c15;" % (n_stages, W, W))
w("  always_ff @(posedge clk) lfsr <= {lfsr[62:0], lfsr[63] ^ lfsr[62] ^ lfsr[60] ^ lfsr[59]} ^ seed;")
for s in range(n_stages):
    a = "{%d{lfsr}}" % (W // 64) if s == 0 else "st[%d]" % (s - 1)
    b = "st[%d]" % ((s + 7) % n_stages)
    c = "nbr" if s == n_stages // 2 else "st[%d]" % ((s * 5 + 3) % n_stages)
    o1, o2, o3, o4 = (rng.choice(ops) for _ in range(4))
    r1, r2 = rng.randrange(1, W - 1), rng.randrange(1, W - 1)
    # 'x' and 'y' are common subexpressions used several times -> DFG temporaries
    w("  wire [%d:0] x%d = (%s %s %s);" % (W - 1, s, a, o1, b))
    w("  wire [%d:0] y%d = ({x%d[%d:0], x%d[%d:%d]} %s %s);" % (W - 1, s, s, r1 - 1, s, W - 1, r1, o2, c))
    w("  wire [%d:0] z%d = ((x%d %s y%d) ^ {y%d[%d:0], y%d[%d:%d]}) %s (x%d & y%d);"
      % (W - 1, s, s, o3, s, s, r2 - 1, s, W - 1, r2, o4, s, s))
    w("  always_ff @(posedge clk) st[%d] <= z%d ^ (x%d | y%d);" % (s, s, s, s))
w("  assign out = st[%d] ^ st[0];" % (n_stages - 1))
w("endmodule")
w("")
w("module t;")
w("  bit clk = 0;")
w("  int cyc = 0;")
w("  wire [%d:0] outs [%d];" % (W - 1, n_inst))
w("  for (genvar i = 0; i < %d; ++i) begin : g" % n_inst)
w("    core c (.clk, .seed(64'(i) * 64'h2545F4914F6CDD1D + 1), .nbr(outs[(i + 1) %% %d]), .out(outs[i]));" % n_inst)
w("  end")
w("  always #1 clk = ~clk;")
w("  always @(posedge clk) begin")
w("    cyc <= cyc + 1;")
w("    if (cyc == %d) begin" % cycles)
w("      logic [63:0] h; h = 0;")
# Fold every 64-bit slice of each output into the hash (a slice XORed with
# itself would be constant folded, making the whole datapath dead code)
fold = " ^ ".join("outs[i][%d:%d]" % (lo + 63, lo) for lo in range(0, W, 64))
w("      for (int i = 0; i < %d; ++i) h = {h[62:0], h[63]} ^ %s;" % (n_inst, fold))
w('      $display("hash %x", h);')
w('      $write("*-* All Finished *-*\\n");')
w("      $finish;")
w("    end")
w("  end")
w("endmodule")
print("\n".join(L))
