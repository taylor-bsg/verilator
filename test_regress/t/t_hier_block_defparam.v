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
  int data[4], result[4];
  int reference[4] = '{default: 0};
  assign data[0] = cycle * 7 + 1;
  assign data[1] = cycle * 11 + 2;
  assign data[2] = cycle * 13 + 3;
  assign data[3] = cycle * 17 + 4;
  boundary a (
      clk,
      data[0],
      result[0]
  );
  boundary b (
      clk,
      data[1],
      result[1]
  );
  boundary c (
      clk,
      data[2],
      result[2]
  );
  container wrapped (
      clk,
      data[3],
      result[3]
  );
  // These set the boundary's own formal and must remain supported.
  defparam a.P = 2; defparam b.P = 3; defparam wrapped.inst.P = 5;

  always @(posedge clk) begin
    reference[0] <= reference[0] + data[0] + 3;
    reference[1] <= reference[1] + data[1] + 4;
    reference[2] <= reference[2] + data[2] + 1;
    reference[3] <= reference[3] + data[3] + 6;
  end
  always @(negedge clk) begin
    int model_threads;
    for (int i = 0; i < 4; ++i) `checkd(result[i], reference[i]);
    cycle <= cycle + 1;
    if (cycle == 100) begin
`ifdef VERILATOR
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 4);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

module container (
    input clk,
    input int data,
    output int result
);
  boundary inst (
      clk,
      data,
      result
  );
endmodule

module boundary #(
    parameter int P = 0
) (
    input clk,
    input int data,
    output int result
);
  /*verilator hier_block*/
  int first, second;
  int state = 0;
  leaf child (first);
  middle mid (second);
  // Local descendant overrides are replayed from this library's original RTL.
  defparam child.N = P; defparam mid.child.N = 1;
  always @(posedge clk) state <= state + data + first + second;
  assign result = state;
endmodule

module middle (
    output int value
);
  leaf child (value);
endmodule

module leaf #(
    parameter int N = 9
) (
    output int value
);
  assign value = N;
endmodule
