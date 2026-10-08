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

typedef byte unsigned ubyte1_t[1];

// The width depends on an array override, converted to the parameter's element type
module m_ta #(
    parameter byte B[1] = '{1},
    parameter logic [(B[0] < 0 ? 8 : 1)-1:0] P = '0
) ();
endmodule

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

// The width depends on the size of a variable in the module
module m_bits;
  logic [4:0] w5;
  parameter logic [$bits(w5)-1:0] S = '0;
endmodule

// The type is a type parameter whose default is a typedef in the module
module m_tdef;
  typedef logic [3:0] nib_t;
  parameter type T = nib_t;
  parameter T Q = '0;
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

// The width comes from the class's own function, so equal values must be one class
class cfn #(
    parameter int M = 2,
    parameter logic [f()-1:0] P = '0
);
  static int count;
  static function int f();
    return M + 1;
  endfunction
endclass

module t;
  m_ta #(.B(ubyte1_t'{8'hff}), .P(8'h01)) i_ta1 ();
  m_ta #(.B(ubyte1_t'{8'hff}), .P(8'h81)) i_ta81 ();
  m_us #(.P(3'b001)) i_us1 ();
  m_us #(.P(3'b101)) i_us5 ();
  m_en #(.N(4), .P(3'd5)) i_en ();
  m_bits #(.S(5'h15)) i_bits15 ();
  m_bits #(.S(5'h0a)) i_bits0a ();
  m_tdef #(.Q(4'h5)) i_tdef5 ();
  m_tdef #(.Q(4'ha)) i_tdefa ();
  ifc #(.P(3'b001)) i_ifc1 ();
  ifc #(.P(3'b101)) i_ifc5 ();
  typedef cls#(.P(3'b001)) cls1_t;
  typedef cls#(.P(3'b101)) cls5_t;
  typedef cfn#(.P(3'h1)) cfn1_t;
  typedef cfn#(.P(1)) cfn1b_t;  // The same value, written at another width
  cfn1_t cfn_a;
  cfn1b_t cfn_b;

  initial begin
    `checkd($bits(i_ta1.P), 8);
    `checkd(i_ta1.P, 8'h01);
    `checkd(i_ta81.P, 8'h81);
    `checkd($bits(i_us1.P), 3);
    `checkd(i_us1.P, 1);
    `checkd(i_us5.P, 5);
    `checkd($bits(i_en.x), 4);
    `checkd($bits(i_en.P), 3);
    `checkd(i_en.P, 5);
    `checkd($bits(i_bits15.S), 5);
    `checkd(i_bits15.S, 5'h15);
    `checkd(i_bits0a.S, 5'h0a);
    `checkd($bits(i_tdef5.Q), 4);
    `checkd(i_tdef5.Q, 4'h5);
    `checkd(i_tdefa.Q, 4'ha);
    `checkd(i_ifc1.P, 1);
    `checkd(i_ifc5.P, 5);
    cls1_t::count = 1;
    cls5_t::count = 5;
    `checkd(cls1_t::count, 1);  // Different values, so different classes
    `checkd(cls5_t::P, 5);
    cfn1_t::count = 3;
    `checkd(cfn1b_t::count, 3);  // The same values, so the same class
    cfn_a = new;
    cfn_b = cfn_a;  // Only legal for the same class
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
