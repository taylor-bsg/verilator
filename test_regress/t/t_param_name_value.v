// DESCRIPTION: Verilator: Verilog Test module
//
// A specialization is named by the value a parameter holds in the instance, also when
// the parameter's type depends on the instance's other parameters.
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Michael Bedford Taylor
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

package pkg;
  typedef enum logic [1:0] {PA, PB, PC} pe_t;
endpackage

// The width depends on a one-bit parameter whose default is '1
module m_us #(
    parameter logic N = '1,
    parameter logic [N+1:0] P = '0
) ();
endmodule

// The width depends on an item of an enum sized by another parameter
module m_en;
  parameter int N = 2;
  typedef enum logic [N-1:0] {EA, EB, EC} e_t;
  parameter int I = int'(EC);
  parameter logic [I:0] P = '0;
  e_t x;
endmodule

// The width depends on an item of a package's enum
module m_pen #(
    parameter int I = int'(pkg::PC),
    parameter logic [I:0] P = '0
) ();
endmodule

// The width depends on a parameter without a type
module m_imp #(
    parameter N = 2,
    parameter logic [N:0] P = '0
) ();
endmodule

// The width depends on the size of a variable in the module
module m_bits;
  logic [4:0] w5;
  parameter logic [$bits(w5)-1:0] S = '0;
endmodule

interface ifc #(
    parameter logic N = '1,
    parameter logic [N+1:0] P = '0
);
endinterface

class cls #(
    parameter logic N = '1,
    parameter logic [N+1:0] P = '0
);
  static int count;
endclass

// Equal values share a class, also when the width's own type is a typedef of the class
class ctd #(
    parameter logic [N-1:0] P = '0
);
  typedef int n_t;
  localparam n_t N = 4;
  static int count;
endclass

// ... or depends on a variable of the class
class cvw #(
    parameter logic [N-1:0] P = '0
);
  logic [3:0] data;
  localparam logic [$bits(data)-1:0] N = 4;
  static int count;
endclass

// The width's own type calls a function, which doesn't see the instance's M
module m_fn #(
    parameter int M = 2,
    parameter logic [f()-1:0] N = 8,
    parameter logic [N-1:0] P = '0
) ();
  function automatic int f();
    return M + 1;
  endfunction
endmodule

// A type parameter is overridden with an unpacked array
typedef int arr2_t[2];
module m_tp #(
    parameter type T = int,
    parameter T N = 0,
    parameter logic [$bits(N)-1:0] P = '0
) ();
endmodule

module t;
  m_us #(.P(3'b001)) i_us1 ();
  m_us #(.P(3'b101)) i_us5 ();
  m_en #(.N(4), .P(3'd5)) i_en ();
  m_pen #(.P(3'd5)) i_pen ();
  m_imp #(.P(3'd5)) i_imp ();
  m_bits #(.S(5'h15)) i_bits15 ();
  m_bits #(.S(5'h0a)) i_bits0a ();
  ifc #(.P(3'b001)) i_ifc1 ();
  ifc #(.P(3'b101)) i_ifc5 ();
  typedef cls#(.P(3'b001)) cls1_t;
  typedef cls#(.P(3'b101)) cls5_t;
  typedef ctd#(.P(4'h1)) ctd1_t;
  typedef ctd#(.P(1)) ctd1b_t;  // The same value, written at another width
  ctd1_t ctd_a;
  ctd1b_t ctd_b;
  typedef cvw#(.P(4'h1)) cvw1_t;
  typedef cvw#(.P(1)) cvw1b_t;
  m_fn #(.M(5), .P(8'h01)) i_fn1 ();
  m_fn #(.M(5), .P(8'h81)) i_fn81 ();
  m_tp #(.T(arr2_t), .N(arr2_t'{1, 2}), .P(64'h8000000000000001)) i_tp ();

  initial begin
    `checkd($bits(i_us1.P), 3);
    `checkd(i_us1.P, 1);
    `checkd(i_us5.P, 5);
    `checkd($bits(i_en.x), 4);
    `checkd($bits(i_en.P), 3);
    `checkd(i_en.P, 5);
    `checkd($bits(i_pen.P), 3);
    `checkd(i_pen.P, 5);
    `checkd($bits(i_imp.P), 3);
    `checkd(i_imp.P, 5);
    `checkd($bits(i_bits15.S), 5);
    `checkd(i_bits15.S, 5'h15);
    `checkd(i_bits0a.S, 5'h0a);
    `checkd(i_ifc1.P, 1);
    `checkd(i_ifc5.P, 5);
    cls1_t::count = 1;
    cls5_t::count = 5;
    `checkd(cls1_t::count, 1);  // Different values, so different classes
    `checkd(cls5_t::P, 5);
    ctd1_t::count = 3;
    `checkd(ctd1b_t::count, 3);  // The same values, so the same class
    ctd_a = new;
    ctd_b = ctd_a;  // Only legal for the same class
    cvw1_t::count = 4;
    `checkd(cvw1b_t::count, 4);
    `checkd(i_fn1.P, 8'h01);
    `checkd(i_fn81.P, 8'h81);
    `checkd($bits(i_tp.P), 64);
    `checkd(i_tp.P, 64'h8000000000000001);
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
