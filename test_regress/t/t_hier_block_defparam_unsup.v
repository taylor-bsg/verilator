// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t;
  boundary a ();
  boundary b ();
  cfg_boundary c ();
  outward d ();
  leaf outside ();
  // These overrides enter a library body and would be lost in its child run.
  defparam a.child.N = 2; defparam b.child.N = 3; defparam c.child.N = 4;
endmodule

module boundary #(
    parameter int P = 0
);
  /*verilator hier_block*/
  leaf child ();
endmodule

module cfg_boundary;
  leaf child ();
endmodule

module outward;
  /*verilator hier_block*/
  defparam t.outside.N = 5;
endmodule

module leaf #(
    parameter int N = 1
);
endmodule
