// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module entry_group (
    input clk,
    input [6:0] in,
    output [6:0] source,
    output [6:0] result
);
  /*verilator threads_group*/
  reg [6:0] state_q = 0;
  always @(posedge clk) state_q = state_q + 7'd1;
  assign source = state_q;
  assign result = state_q + in;
endmodule

module t (
    input clk
);
  integer cyc = 1;
  reg [6:0] external_q = 3;
  always @(posedge clk) external_q <= external_q + 7'd3;

  // The group's source is ready independently of the external input.
  wire [6:0] source;
  wire [6:0] result;
  entry_group direct (
      .clk(clk),
      .in(external_q),
      .source(source),
      .result(result)
  );

  // This path leaves the group and re-enters it without an RTL cycle.
  wire [6:0] feedback_source;
  wire [6:0] feedback_result;
  wire [6:0] feedback = feedback_source ^ external_q;
  entry_group returned (
      .clk(clk),
      .in(feedback),
      .source(feedback_source),
      .result(feedback_result)
  );

  always @(negedge clk) begin
    `checkh(source, 7'(cyc))
    `checkh(feedback_source, 7'(cyc))
    `checkh(result, 7'(4 * cyc + 3))
    `checkh(feedback_result, 7'(cyc + (cyc ^ (3 * cyc + 3))))
    cyc <= cyc + 1;
    if (cyc == 40) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
