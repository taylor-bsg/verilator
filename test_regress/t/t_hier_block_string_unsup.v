// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  leaf #(.S("nl\nx")) newline_literal ();
  leaf #(.S({"prefix", "\n", "suffix"})) newline_expression ();
  leaf #(.S("q\"t")) quoted ();
  middle #(.S("nested\nvalue")) nested ();
  // Converting a packed integral literal to the formal string is also checked.
  leaf #(.S(16'h610a)) converted ();
endmodule

module leaf #(
    parameter string S = "default"
);
  /*verilator hier_block*/
  initial $display("%s", S);
endmodule

module middle #(
    parameter string S = "default"
);
  /*verilator hier_block*/
  leaf #(.S({S, "!"})) child ();
endmodule
