// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

`ifndef CHILD_THREADS
`define CHILD_THREADS 1
`endif

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d: %m got=%0d exp=%0d (%s !== %s)\n", `__FILE__, `__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while (0);
// verilog_format: on

module t (
    input clk
);
  int cycle = 0;
  checked #(
      .ID(1),
      .HASH(32'h21832aca),
      .DEFAULTS(1)
  ) c0 (
      .*
  );
  checked #(
      .ID(2),
      .HASH(32'h21832aca),
      .DEFAULTS(1)
  ) c1 (
      .*
  );
  checked #(
      .ID(3),
      .HASH(32'h00000000),
      .S("")
  ) c2 (
      .*
  );
  checked #(
      .ID(4),
      .HASH(32'h03cb1ede),
      .S("nl x")
  ) c3 (
      .*
  );
  checked #(
      .ID(5),
      .HASH(32'h000a3596),
      .S("a\tb")
  ) c4 (
      .*
  );
  checked #(
      .ID(6),
      .HASH(32'h000a36e2),
      .S("a\rb")
  ) c5 (
      .*
  );
  checked #(
      .ID(7),
      .HASH(32'h75fa3092),
      .S("a,b'\\z")
  ) c6 (
      .*
  );
  checked #(
      .ID(8),
      .HASH(32'h3267ac59),
      .S(" leading and trailing ")
  ) c7 (
      .*
  );
  checked #(
      .ID(9),
      .HASH(32'h4c1166ab),
      .S("// /* comment */"),
      .NESTED(1)
  ) c8 (
      .*
  );
  checked #(
      .ID(10),
      .HASH(32'h6852389f),
      .S("$HOME")
  ) c9 (
      .*
  );
  checked #(
      .ID(11),
      .HASH(32'h3bf2fc02),
      .S("back\\slash\\n")
  ) c10 (
      .*
  );
  checked #(
      .ID(12),
      .HASH(32'h03cb1ede),
      .S("nl x")
  ) c11 (
      .*
  );
  checked #(
      .ID(13),
      .HASH(32'h4f8836a3),
      .S("x // comment")
  ) c12 (
      .*
  );
  checked #(
      .ID(14),
      .HASH(32'h019e888c),
      .S("/**/")
  ) c13 (
      .*
  );
  checked #(
      .ID(15),
      .HASH(32'h39685f1e),
      .S("back\\/* comment */")
  ) c14 (
      .*
  );
  checked #(
      .ID(16),
      .HASH(32'h037ce4bd),
      .S("end\\")
  ) c15 (
      .*
  );
  // Integral-to-string conversion removes zero bytes before transport.
  checked #(
      .ID(17),
      .HASH(32'h00001fd5),
      .S("a\000b")
  ) c16 (
      .*
  );
  always @(negedge clk) begin
    cycle <= cycle + 1;
    if (cycle == 127) begin
`ifdef VERILATOR
      int model_threads;
      model_threads = $c("Verilated::threadContextp()->threadsInModels()");
      `checkd(model_threads, `ROOT_THREADS + 18 * `CHILD_THREADS);
`endif
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule

// Expected hashes use the original bytes, independently of child transport.
module checked #(
    parameter string S = "unused",
    parameter int ID = 0,
    parameter int unsigned HASH = 0,
    parameter bit DEFAULTS = 0,
    NESTED = 0
) (
    input clk
);
  int cycle = 0;
  int unsigned data, out, reference = 0;
  logic reset;
  assign data = 32'(cycle * (ID + 7) + ID * 31);
  assign reset = cycle % (19 + ID) == 0;
  if (DEFAULTS) begin
    // Unoverridden strings are read from the child RTL and need no transport.
    leaf dut (.*);
  end
  else if (NESTED) begin
    middle #(.S(S)) dut (.*);
  end
  else begin
    leaf #(.S(S)) dut (.*);
  end
  always @(posedge clk) begin
    if (reset) reference <= 0;
    else reference <= reference + (data ^ HASH);
  end
  always @(negedge clk) begin
    `checkd(out, reference);
    cycle <= cycle + 1;
  end
endmodule

module leaf #(
    parameter string S = "line\n\"quoted\""
) (
    input clk,
    reset,
    input int unsigned data,
    output int unsigned out
);
  /*verilator hier_block*/
  function automatic int unsigned hash_string();
    hash_string = 0;
    for (int i = 0; i < S.len(); ++i) hash_string = hash_string * 83 + 32'(S.getc(i));
  endfunction
  int unsigned state = 0;
  always @(posedge clk) begin
    if (reset) state <= 0;
    else state <= state + (data ^ hash_string());
  end
  assign out = state;
endmodule

module middle #(
    parameter string S = "unused"
) (
    input clk,
    reset,
    input int unsigned data,
    output int unsigned out
);
  /*verilator hier_block*/
  leaf #(.S(S)) child (.*);
endmodule
