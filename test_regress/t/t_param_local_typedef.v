// DESCRIPTION: Verilator: Verilog Test module
//
// Overridden parameters whose types are typedefs of the module. Since #8537,
// these give an internal error when no instance keeps the defaults, as the
// type table keeps references into the deleted template (issue #8546). Also
// the other parameter overrides from t_param_array10 (PR #8535) that master
// handled before #8537.
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Oyvind Janbu
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

// Parameters whose types are typedefs of the module, overridden in every instance
module lta;
  typedef logic [4:0] word_t;
  parameter word_t A[2] = '{default: 0};
endmodule
module lts;
  typedef logic [4:0] word_t;
  parameter word_t S = 0;
endmodule
module ltp;
  typedef struct packed {
    logic [3:0] a;
    logic [3:0] b;
  } pair_t;
  parameter pair_t P = '0;
endmodule
module ltc;
  typedef logic [4:0] word_t;
  typedef word_t word2_t;
  parameter word2_t A[2] = '{default: 0};
endmodule

// The same, with one instance keeping the defaults
module ltk;
  typedef logic [4:0] word_t;
  parameter word_t A[2] = '{default: 7};
endmodule

module m #(
    parameter int N = 1,
    parameter int V[N] = '{0}
) ();
endmodule

// Concatenation value for a parameter with a parameter-dependent width
module c #(
    parameter int W = 1,
    parameter logic [W-1:0] P = '0
) ();
endmodule

// Untyped parameter with a parameter-dependent default value (issue #5890)
module u #(
    parameter LEN = 4,
    parameter LST[LEN] = '{LEN{0}}
) ();
endmodule

// Size from an element of another array parameter
module e #(
    parameter int B[2] = '{1, 1},
    parameter int V[B[0]] = '{0}
) ();
endmodule

// Size from the size of another array parameter
module sz #(
    parameter int B[3] = '{0, 0, 0},
    parameter int V[$size(B)] = '{default: 0}
) ();
endmodule

// Size from a localparam of the parameter port list
module lp #(
    parameter int N = 0,
    localparam int M = N + 1,
    parameter int V[M] = '{default: 0}
) ();
endmodule

typedef int int1_t[1];

module ta #(
    parameter byte B[1] = '{1},
    parameter logic [(B[0] < 0 ? 8 : 1)-1:0] P = '0,
    parameter int V[B[0] < 0 ? 2 : B[0]] = '{default: 0}
) ();
endmodule

// Sizes from one-bit parameters set by the unsized literal '1
module ub #(
    parameter logic [0:0] N = '1,
    parameter int A[N] = '{default: 0}
) ();
endmodule

module ui #(
    parameter N = '1,  // No type or range, so one bit
    parameter int A[N == 1 && $bits(N) == 1 ? 2 : 1] = '{default: 0}
) ();
endmodule

// A typedef holding an enum that depends on a parameter left at its default
module ue;
  parameter int N = 7;
  typedef union packed {
    enum logic [N-1:0] {ZERO = 0} e;
    logic [N-1:0] x;
  } u_t;
  parameter u_t A[2] = '{default: '{x: 0}};
endmodule

// Sizes and types from $bits of a variable of a package or of the module, not a parameter
package pv;
  class pvc;  // A class ahead of the variable
  endclass
  logic [4:0] sig5;
endpackage

module bv #(
    parameter int N = $bits(pv::sig5),
    parameter int V[N] = '{default: 0}
) ();
endmodule

module bw;
  logic [4:0] w5;
  typedef logic [$bits(w5)-1:0] w_t;
  parameter w_t V[2] = '{default: 0};
endmodule

module t;
  localparam logic [0:0] ALL = '1;
  localparam UALL = '1;
  lta #(.A('{3, 17})) i_lta ();
  lts #(.S(9)) i_lts ();
  ltp #(.P('{a: 3, b: 4})) i_ltp ();
  ltc #(.A('{3, 17})) i_ltc ();
  ltk i_ltk0 ();
  ltk #(.A('{3, 17})) i_ltk ();

  ue #(.A('{65, 33})) i_ue ();
  bw #(.V('{17, 18})) i_bw ();
  bv #(.V('{1, 2, 3, 4, 5})) i_bv ();
  c #(.W(16), .P({8'ha, 8'hb})) i_c ();
  e #(.V('{5})) i_ed ();  // Array parameter left at its default
  lp #(.N(3)) i_lpd ();  // Default value must resize with M
  m #(.V('{1})) i_m1 ();  // Size left at its default
  m #(.N(), .V('{7})) i_me ();  // Empty override keeps the default
  sz #(.B('{1, 2, 3}), .V('{7, 8, 9})) i_sz ();
  ta #(.P(1'b1), .B(int1_t'{257}), .V('{5})) i_tb ();  // Truncated to a byte, so B[0] is 1
  ub #(.A('{7})) i_ub ();
  ub #(.N('1), .A('{8})) i_ubo ();
  ub #(.N(ALL), .A('{9})) i_ubp ();  // From the enclosing module's parameter
  u #(.LEN(8)) i_ud ();  // Default value must resize with LEN
  ui #(.A('{1, 2})) i_ui ();
  ui #(.N('1), .A('{3, 4})) i_uio ();
  ui #(.N(UALL), .A('{5, 6})) i_uip ();

  initial begin
    // Parameters whose types are typedefs of the module
    `checkd($bits(i_lta.A[0]), 5);
    `checkd(i_lta.A[1], 17);
    `checkd($bits(i_lts.S), 5);
    `checkd(i_lts.S, 9);
    `checkd(i_ltp.P.a, 3);
    `checkd(i_ltp.P.b, 4);
    `checkd($bits(i_ltc.A[0]), 5);
    `checkd(i_ltc.A[1], 17);
    `checkd(i_ltk0.A[1], 7);
    `checkd(i_ltk.A[1], 17);

    // From t_param_array10
    `checkd($bits(i_ue.A[0].x), 7);
    `checkd(i_ue.A[0].x, 65);
    `checkd(i_ue.A[1].x, 33);
    `checkd($bits(i_bw.V[0]), 5);
    `checkd(i_bw.V[1], 18);
    `checkd($size(i_bv.V), 5);
    `checkd(i_bv.V[4], 5);
    `checkd($bits(i_c.P), 16);
    `checkh(i_c.P, 16'h0a0b);
    `checkd($size(i_ed.V), 1);
    `checkd(i_ed.V[0], 5);
    `checkd($size(i_lpd.V), 4);
    `checkd($size(i_m1.V), 1);
    `checkd(i_m1.V[0], 1);
    `checkd($size(i_me.V), 1);
    `checkd(i_me.V[0], 7);
    `checkd($size(i_sz.V), 3);
    `checkd(i_sz.V[2], 9);
    `checkd(i_tb.B[0], 1);
    `checkd($bits(i_tb.P), 1);
    `checkd($size(i_tb.V), 1);
    `checkd(i_ub.N, 1);
    `checkd($size(i_ub.A), 1);
    `checkd(i_ub.A[0], 7);
    `checkd($size(i_ubo.A), 1);
    `checkd(i_ubo.A[0], 8);
    `checkd($size(i_ubp.A), 1);
    `checkd(i_ubp.A[0], 9);
    `checkd($size(i_ud.LST), 8);
    `checkd($bits(i_ui.N), 1);
    `checkd($size(i_ui.A), 2);
    `checkd($size(i_uio.A), 2);
    `checkd($size(i_uip.A), 2);
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
