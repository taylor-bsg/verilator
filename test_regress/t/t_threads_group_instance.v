// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

// Instantiated both inside each tile and beside the tiles
module rtr (
    input clk,
    input [7:0] in,
    output [7:0] out
);
  reg [7:0] r = 0;
  assign out = r;
  always @(posedge clk) r <= r + in;
endmodule

module tile (
    input clk,
    input [7:0] in,
    output [7:0] out
);
  wire [7:0] q;
  rtr rtr (
      .clk(clk),
      .in(in ^ 8'h5a),
      .out(q)
  );
  reg [7:0] s = 0;
  assign out = s;
  always @(posedge clk) s <= s + q;
endmodule

module t (
    input clk
);
  integer cyc = 0;
  wire [7:0] out[4];
  wire [7:0] io[4];
  for (genvar i = 0; i < 4; ++i) begin : g
    tile u (
        .clk(clk),
        .in(io[i]),
        .out(out[i])
    );
    rtr io_rtr (
        .clk(clk),
        .in(out[(i+3)%4] + 8'(i)),
        .out(io[i])
    );
  end
  always @(posedge clk) begin
    cyc <= cyc + 1;
    if (cyc == 20) begin
      `checkd(out[0], 50)
      `checkd(out[1], 162)
      `checkd(out[2], 106)
      `checkd(out[3], 178)
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
