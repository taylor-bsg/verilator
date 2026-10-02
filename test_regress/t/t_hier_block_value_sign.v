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
  logic reset;
  longint data[10], out[10];
  longint reference[10] = '{default: 0};
  localparam longint STEP[10] = '{-1, -3, -3, -3, 64'shfffffffd, -3, -3, -3, 253, -3};
  assign reset = cycle % 29 == 0;
  for (genvar i = 0; i < 10; ++i) begin : stimulus
    assign data[i] = 64'(cycle * (i + 7) + i * 13);
  end

  // The same bits with different signedness must select different libraries.
  // Unary minus and folding can leave signedness on the dtype, not V3Number.
  leaf #(
      .K(-1)
  ) a0 (
      clk,
      reset,
      data[0],
      out[0]
  );
  leaf #(
      .K(-3)
  ) a1 (
      clk,
      reset,
      data[1],
      out[1]
  );
  leaf #(
      .K(-32'sd3)
  ) a2 (
      clk,
      reset,
      data[2],
      out[2]
  );
  leaf #(
      .K(3 - 6)
  ) a3 (
      clk,
      reset,
      data[3],
      out[3]
  );
  leaf #(
      .K(32'hfffffffd)
  ) a4 (
      clk,
      reset,
      data[4],
      out[4]
  );
  leaf #(
      .K(-3)
  ) a5 (
      clk,
      reset,
      data[5],
      out[5]
  );
  leaf #(
      .K(65'sh1fffffffffffffffd)
  ) a6 (
      clk,
      reset,
      data[6],
      out[6]
  );
  leaf #(
      .K(8'shfd)
  ) a7 (
      clk,
      reset,
      data[7],
      out[7]
  );
  leaf #(
      .K(8'hfd)
  ) a8 (
      clk,
      reset,
      data[8],
      out[8]
  );
  middle #(
      .K(-3)
  ) a9 (
      clk,
      reset,
      data[9],
      out[9]
  );

  always @(posedge clk) begin
    foreach (reference[i]) begin
      if (reset) reference[i] <= 0;
      else reference[i] <= reference[i] + data[i] + STEP[i];
    end
  end
  always @(negedge clk) begin
    foreach (out[i]) `checkd(out[i], reference[i]);
    cycle <= cycle + 1;
    if (cycle == 127) begin
`ifdef VERILATOR
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 11);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

module leaf #(
    parameter K = 0
) (
    input clk,
    reset,
    input longint data,
    output longint out
);
  /*verilator hier_block*/
  longint state = 0;
  always @(posedge clk) begin
    if (reset) state <= 0;
    else state <= state + data + longint'(K);
  end
  assign out = state;
endmodule

module middle #(
    parameter K = 0
) (
    input clk,
    reset,
    input longint data,
    output longint out
);
  /*verilator hier_block*/
  leaf #(.K(K)) child (.*);
endmodule
