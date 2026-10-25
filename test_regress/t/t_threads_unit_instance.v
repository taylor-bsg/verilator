// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__, `__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module instance_router #(
    parameter int ID = 0
) (
    input clk,
    input [30:0] in,
    output [30:0] out
);
`ifdef ROUTER_UNIT
  /*verilator threads_unit*/
`endif
  logic [30:0] state = 31'(ID);
  always @(posedge clk) state <= state + in + 31'(ID);
  assign out = state;
endmodule

module instance_tile (
    input clk,
    input [30:0] in,
    output [30:0] out
);
  // Shares a module specialization with selected routers, but stays inside this tile's unit.
  instance_router rtr (
      .clk(clk),
      .in(in),
      .out(out)
  );
endmodule

module instance_island #(
    parameter int ID = 0
) (
    input clk,
    input [30:0] in,
    output [30:0] tile_out,
    output [30:0] io_out
);
  instance_tile tile (
      .clk(clk),
      .in(in),
      .out(tile_out)
  );
  // The enclosing island and generate blocks may be flattened; match the original local name.
  instance_router #(ID) io_rtr (
      .clk(clk),
      .in(in),
      .out(io_out)
  );
endmodule

module t #(
    parameter int N = 12
) (
    input clk
);
  logic [30:0] cyc = 0;
  wire [30:0] tile_out[N];
  wire [30:0] io_out[N];
  logic [30:0] tile_reference[N];
  logic [30:0] io_reference[N];
  wire [30:0] diag_out;
  logic [30:0] diag_reference = 0;
  instance_router diag (
      .clk(clk),
      .in(cyc ^ 31'h123),
      .out(diag_out)
  );
  wire [30:0] array_out[2:1];
  wire [30:0] probe_out;
  logic [30:0] extra_reference = 0;
  instance_router arr_rtr[2:1] (
      .clk(clk),
      .in(cyc),
      .out({array_out[2], array_out[1]})
  );
  instance_router \probe.dot (
      .clk(clk),
      .in(cyc),
      .out(probe_out)
  );
  for (genvar i = 0; i < N; ++i) begin : g
    instance_island #(i % 2) island (
        .clk(clk),
        .in(cyc + 31'(i)),
        .tile_out(tile_out[i]),
        .io_out(io_out[i])
    );
    initial begin
      tile_reference[i] = 0;
      io_reference[i] = 31'(i % 2);
    end
    always @(posedge clk) begin
      `checkh(tile_out[i], tile_reference[i])
      `checkh(io_out[i], io_reference[i])
      tile_reference[i] <= tile_reference[i] + cyc + 31'(i);
      io_reference[i] <= io_reference[i] + cyc + 31'(i) + 31'(i % 2);
    end
  end
  always @(posedge clk) begin
    `checkh(diag_out, diag_reference)
    `checkh(array_out[1], extra_reference)
    `checkh(array_out[2], extra_reference)
    `checkh(probe_out, extra_reference)
    extra_reference <= extra_reference + cyc;
    diag_reference <= diag_reference + (cyc ^ 31'h123);
    cyc <= cyc + 1;
    if (cyc == 40) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
