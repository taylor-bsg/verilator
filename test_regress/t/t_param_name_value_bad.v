// DESCRIPTION: Verilator: Verilog Test module
//
// Errors for parameters whose values another parameter's type depends on, when naming
// a specialization.
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

module m_var #(
    parameter int N = 1,
    parameter logic [N:0] P = '0
) ();
endmodule

module m_none #(
    parameter int N,
    parameter logic [N:0] P = '0
) ();
endmodule

module m_cycle #(
    parameter int A = B,
    parameter int B = A,
    parameter logic [A:0] P = '0
) ();
endmodule

module m_rand #(
    parameter int N = $random,
    parameter logic [N:0] P = '0
) ();
endmodule

module t;
  int x;
  m_var #(.P(3'd5), .N(x)) i_var ();  // Not a constant
  m_none #(.P(3'd5)) i_none ();  // No value
  m_cycle #(.P(3'd5)) i_cycle ();  // Circular
  m_rand #(.P(3'd5)) i_rand ();  // Not a constant default
endmodule
