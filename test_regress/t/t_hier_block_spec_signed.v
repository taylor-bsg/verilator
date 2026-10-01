// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: %m got=%0d exp=%0d (%s !== %s)\n", `__FILE__, `__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while (0);
// verilog_format: on

module t (
    input clk
);
  int cycle = 0;
  int data0, data1;
  longint a, b, c;
  logic [6:0] ref0 = 0, ref1 = 0;
  assign data0 = cycle * 17 + 3;
  assign data1 = cycle * 23 + 5;
  leaf #(
      .T(logic signed [6:0])
  ) signed0 (
      .clk,
      .data(data0),
      .out(a)
  );
  leaf #(
      .T(logic [6:0])
  ) unsigned0 (
      .clk,
      .data(data0),
      .out(b)
  );
  leaf #(
      .T(logic signed [6:0])
  ) signed1 (
      .clk,
      .data(data1),
      .out(c)
  );
  always @(posedge clk) begin
    ref0 <= ref0 + 7'(data0);
    ref1 <= ref1 + 7'(data1);
  end
  always @(negedge clk) begin
    int model_threads;
    // Identical numeric parameters, identical widths, different signedness.
    // A wrong wrapper passes width checks but fails these behavioral checks.
    `checkd(a, longint'($signed(ref0)) >>> 1);
    `checkd(b, longint'(ref0) >> 1);
    `checkd(c, longint'($signed(ref1)) >>> 1);
    cycle <= cycle + 1;
    if (cycle == 127) begin
`ifdef VERILATOR
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 3);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

module leaf #(
    parameter type T = logic [6:0]
) (
    input clk,
    input int data,
    output longint out
);
  /*verilator hier_block*/
  T state = 0;
  always @(posedge clk) state <= state + T'(data);
  assign out = longint'(T'(state >>> 1));
endmodule
