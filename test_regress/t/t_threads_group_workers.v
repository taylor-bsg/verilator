// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module worker_tile #(
    parameter int ID = 0
) (
    input clk,
    input [31:0] in,
    output [31:0] out
);
  logic [31:0] state = ID;
  // Instance zero has no clocked work, but still occupies list index zero.
  if (ID != 0) begin : clocked
    always @(posedge clk) state <= state + in + ID;
  end
  assign out = state ^ ID;
endmodule

module t #(
    parameter int N = 16
) (
    input clk
);
  integer cyc = 0;
  wire [31:0] out[N];
  logic [31:0] reference_state[N];
  for (genvar i = 0; i < N; ++i) begin : g
    worker_tile #(i) u (
        .clk(clk),
        .in(out[(i+N-1)%N]),
        .out(out[i])
    );
    initial reference_state[i] = i;
    always @(posedge clk) begin
      `checkh(out[i], reference_state[i] ^ i)
      if (i != 0)
        reference_state[i] <= reference_state[i] + (reference_state[(i+N-1)%N] ^ ((i+N-1)%N)) + i;
    end
  end
  always @(posedge clk) begin
    cyc <= cyc + 1;
    if (cyc == 40) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
