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
  checked #(
      .T(logic [6:0]),
      .ID(1)
  ) c0 (
      .*
  );
  checked #(
      .T(logic [14:0]),
      .ID(2)
  ) c1 (
      .*
  );
  checked #(
      .T(logic [6:0]),
      .ID(3)
  ) c2 (
      .*
  );
  checked #(
      .T(logic [3:0]),
      .PLAIN(1),
      .ID(4)
  ) c3 (
      .*
  );
  checked #(
      .T(logic [3:0]),
      .PLAIN(1),
      .ID(5)
  ) c4 (
      .*
  );
  always @(negedge clk) begin
    cycle <= cycle + 1;
    if (cycle == 150) begin
`ifdef VERILATOR
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 5);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

module checked #(
    parameter type T = logic [6:0],
    parameter bit PLAIN = 0,
    parameter int ID = 0
) (
    input clk
);
  int cycle = 0;
  int data, out[3];
  logic reset;
  int reference[3] = '{default: 0};
  int shadow_reference[3] = '{default: 0};
  assign data = cycle * 37 + ID * 53;
  assign reset = cycle % (19 + ID) == 0;
  if (PLAIN) plain dut (.*);
  else typed #(.T(T)) dut (.*);
  always @(posedge clk) begin
    foreach (reference[i]) begin
      if (reset) begin
        reference[i] <= 0;
        shadow_reference[i] <= 0;
      end
      else begin
        reference[i] <= (reference[i] + data + i) & ((1 << ($bits(T) + i)) - 1);
        shadow_reference[i] <= (shadow_reference[i] + data + i + 1) & 7;
      end
    end
  end
  always @(negedge clk) begin
    foreach (out[i]) `checkd(out[i], reference[i] * 8 + shadow_reference[i]);
    cycle <= cycle + 1;
  end
endmodule

module typed #(
    parameter type T = logic
) (
    input clk,
    reset,
    input int data,
    output int out[3]
);
  /*verilator hier_block*/
  for (genvar i = 0; i < 3; ++i) begin : g
    localparam type E = logic [$bits(T)+i-1:0];
    E state = 0;
    always @(posedge clk) begin
      if (reset) state <= 0;
      else state <= state + E'(data + i);
    end
    if (1) begin : shadow
      localparam type T = logic [2:0];
      T state = 0;
      always @(posedge clk) begin
        if (reset) state <= 0;
        else state <= state + T'(data + i + 1);
      end
    end
    assign out[i] = int'(state) * 8 + int'(shadow.state);
  end
endmodule

module plain (
    input clk,
    reset,
    input int data,
    output int out[3]
);
  /*verilator hier_block*/
  // None of these declarations is a formal type parameter to transport.
  localparam type T = logic [3:0];
  for (genvar i = 0; i < 3; ++i) begin : g
    localparam type E = logic [$bits(T)+i-1:0];
    E state = 0;
    always @(posedge clk) begin
      if (reset) state <= 0;
      else state <= state + E'(data + i);
    end
    if (1) begin : shadow
      localparam type T = logic [2:0];
      T state = 0;
      always @(posedge clk) begin
        if (reset) state <= 0;
        else state <= state + T'(data + i + 1);
      end
    end
    assign out[i] = int'(state) * 8 + int'(shadow.state);
  end
endmodule
