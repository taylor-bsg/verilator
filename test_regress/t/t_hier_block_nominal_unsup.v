// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

class item;
  int value;
endclass

module t (
    input clk
);
  typedef struct packed {logic [6:0] value;} local_t;
  blocked #(.T(local_t)) local_type (.clk);
  blocked #(.T(struct packed {logic [6:0] value;})) anonymous_type (.clk);
  blocked #(.T(item)) class_type (.clk);
endmodule

module blocked #(
    parameter type T = logic
) (
    input clk
);
  /*verilator hier_block*/
endmodule
